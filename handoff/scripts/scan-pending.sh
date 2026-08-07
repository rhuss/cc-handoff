#!/usr/bin/env bash
#
# scan-pending.sh
#
# SessionStart hook script for the session-handoff skill.
# Scans ~/.claude/handoffs/ for pending (unconsumed) handoff documents
# across all project subdirectories and outputs a compact notification for the agent.
# Respects the `notification` key in ~/.claude/handoffs/config.yml:
#   proactive (default) - outputs notification with MUST-mention directive
#   passive             - outputs notification tag without directive
#   quiet               - exits silently, no output
#
# Exit codes:
#   0 - always (per EH-002: fail silently, never block session start)

set -euo pipefail

HANDOFFS_DIR="$HOME/.claude/handoffs"

# --- Utility Functions ---

# get_project_slug: prints the project slug to stdout
# Delegates to the shared get-project-slug.sh script.
get_project_slug() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  bash "$script_dir/get-project-slug.sh"
}

# extract_frontmatter_field: extracts a YAML frontmatter field value from a file
# Usage: extract_frontmatter_field <file> <field>
# Returns: the field value (unquoted), or empty string if not found
extract_frontmatter_field() {
  local file="$1"
  local field="$2"
  local value

  # Read between the first two --- lines, extract the field
  value=$(sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null \
    | grep "^${field}:" \
    | head -1 \
    | sed "s/^${field}:[[:space:]]*//" \
    | sed 's/^["'\'']\(.*\)["'\''"]$/\1/' || true)

  echo "$value"
}

# format_date_short: converts a date prefix to "Mon DD" for compact display
# Handles both "20260804" (old format) and "2026-08-04" (new format)
# Returns: "Aug 4"
format_date_short() {
  local ts="$1"
  local month day

  if [[ "$ts" == *-*-* ]]; then
    # New format: 2026-08-04
    month="${ts:5:2}"
    day="${ts:8:2}"
  else
    # Old format: 20260804
    month="${ts:4:2}"
    day="${ts:6:2}"
  fi

  day="${day#0}"

  local month_names=("" "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
  local month_idx=$((10#$month))

  echo "${month_names[$month_idx]} ${day}"
}

# --- Main Script ---

main() {
  # Exit silently if handoffs directory does not exist (EH-002)
  if [ ! -d "$HANDOFFS_DIR" ]; then
    exit 0
  fi

  # Read notification mode from config (default: proactive)
  local config="$HOME/.claude/handoffs/config.yml"
  local notification_mode="proactive"

  if [ -f "$config" ]; then
    local val=""
    if command -v yq &>/dev/null; then
      val=$(yq -r '.notification' "$config" 2>/dev/null)
    else
      val=$(grep -E '^notification:' "$config" 2>/dev/null | sed 's/^notification:[[:space:]]*//' | tr -d " \"'")
    fi

    if [ -n "$val" ] && [ "$val" != "null" ]; then
      case "$val" in
        proactive|passive|quiet)
          notification_mode="$val"
          ;;
        *)
          echo "Warning: Invalid notification value '$val' in config.yml, using default 'proactive'" >&2
          ;;
      esac
    fi
  fi

  # Read auto_handoff config (default: false)
  local auto_handoff="false"

  if [ -f "$config" ]; then
    local ah_val=""
    if command -v yq &>/dev/null; then
      ah_val=$(yq -r '.auto_handoff' "$config" 2>/dev/null)
    else
      ah_val=$(grep -E '^auto_handoff:' "$config" 2>/dev/null | sed 's/^auto_handoff:[[:space:]]*//' | tr -d " \"'")
    fi

    if [ -n "$ah_val" ] && [ "$ah_val" != "null" ]; then
      case "$ah_val" in
        true|True|TRUE)
          auto_handoff="true"
          ;;
        false|False|FALSE)
          auto_handoff="false"
          ;;
        *)
          echo "Warning: Invalid auto_handoff value '$ah_val' in config.yml, using default 'false'" >&2
          ;;
      esac
    fi
  fi

  if [ "$notification_mode" = "quiet" ]; then
    exit 0
  fi

  local current_slug
  current_slug=$(get_project_slug)

  # Promote orphaned drafts to pending handoffs
  if [ "$auto_handoff" = "true" ]; then
    local drafts_dir="$HANDOFFS_DIR/${current_slug}/drafts"
    if [ -d "$drafts_dir" ]; then
      for draft_file in "$drafts_dir"/*.md; do
        [ ! -f "$draft_file" ] && continue
        local draft_basename
        draft_basename=$(basename "$draft_file")
        local target="$HANDOFFS_DIR/${current_slug}/${draft_basename}"
        if [ -f "$target" ]; then
          local suffix=1
          local base="${draft_basename%.md}"
          while [ -f "$HANDOFFS_DIR/${current_slug}/${base}-${suffix}.md" ]; do
            suffix=$((suffix + 1))
          done
          target="$HANDOFFS_DIR/${current_slug}/${base}-${suffix}.md"
        fi
        mv "$draft_file" "$target" 2>/dev/null || \
          echo "Warning: Failed to promote draft: $draft_file" >&2
      done
    fi
  fi

  local current_count=0
  local cross_count=0
  local latest_ts=""

  # Scan all project subdirectories, counting handoffs per category
  for project_dir in "$HANDOFFS_DIR"/*/; do
    [ ! -d "$project_dir" ] && continue

    local project_name
    project_name=$(basename "$project_dir")
    [ "$project_name" = "consumed" ] && continue
    [ "$project_name" = "drafts" ] && continue

    for handoff_file in "$project_dir"*.md; do
      [ ! -f "$handoff_file" ] && continue

      # Skip empty files (EH-003)
      if [ ! -s "$handoff_file" ]; then
        echo "Warning: Skipping empty handoff file: $handoff_file" >&2
        continue
      fi

      local summary
      summary=$(extract_frontmatter_field "$handoff_file" "summary")

      # Skip files with missing frontmatter (EH-003)
      if [ -z "$summary" ]; then
        echo "Warning: Skipping handoff with missing summary: $handoff_file" >&2
        continue
      fi

      if [ "$project_name" = "$current_slug" ]; then
        current_count=$((current_count + 1))
        local filename
        filename=$(basename "$handoff_file")
        # Extract date prefix for "latest" comparison
        # Handles both old format (20260805-094822.md) and new format (2026-08-05-warm-pool-api.md)
        local ts_raw
        ts_raw=$(echo "$filename" | grep -oE '^[0-9]{4}-?[0-9]{2}-?[0-9]{2}')
        if [ -z "$latest_ts" ] || [[ "$ts_raw" > "$latest_ts" ]]; then
          latest_ts="$ts_raw"
        fi
      else
        cross_count=$((cross_count + 1))
      fi
    done
  done

  # Silent exit if no handoffs anywhere
  if [ "$current_count" -eq 0 ] && [ "$cross_count" -eq 0 ]; then
    exit 0
  fi

  # Build compact notification message
  local message=""
  if [ "$current_count" -gt 0 ]; then
    local label="handoffs"
    [ "$current_count" -eq 1 ] && label="handoff"
    local latest_display
    latest_display=$(format_date_short "$latest_ts")
    message="${current_count} ${label} available (latest: ${latest_display})."
    if [ "$cross_count" -gt 0 ]; then
      message="${message} +${cross_count} from other projects."
    fi
    message="${message} Say \"load handoff\" to pick one up, or \"load latest handoff\" to skip selection."
  else
    local label="handoffs"
    [ "$cross_count" -eq 1 ] && label="handoff"
    message="${cross_count} ${label} available from other projects. Say \"load handoff\" to browse them."
  fi

  local content
  if [ "$notification_mode" = "proactive" ]; then
    content="<handoff-notify>${message}</handoff-notify>

IMPORTANT: You MUST mention these pending handoffs to the user before responding to their first message."
  else
    content="<handoff-notify>${message}</handoff-notify>"
  fi

  # Escape for JSON embedding
  local escaped
  escaped="${content//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  escaped="${escaped//$'\n'/\\n}"
  escaped="${escaped//$'\r'/\\r}"
  escaped="${escaped//$'\t'/\\t}"

  # Output as hookSpecificOutput JSON for Claude Code plugin hooks
  printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$escaped"
}

# EH-002 requires the script always exits 0.
# EH-003 warnings go to stderr and are visible to the session.
main "$@" || true
