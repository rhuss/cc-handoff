#!/usr/bin/env bash
#
# scan-pending-handoffs.sh
#
# SessionStart hook script for the session-handoff skill.
# Scans ~/.claude/handoffs/ for pending (unconsumed) handoff documents
# across all project subdirectories and outputs a listing for the agent.
#
# Exit codes:
#   0 - always (per EH-002: fail silently, never block session start)

set -euo pipefail

HANDOFFS_DIR="$HOME/.claude/handoffs"

# --- Utility Functions ---

# get_project_slug: prints the project slug to stdout
# Returns: repository name from git remote, or basename of $PWD, or "unknown-project"
# NOTE: This algorithm must match the slug derivation in SKILL.md step 1.
get_project_slug() {
  local remote_url slug

  remote_url=$(git remote get-url origin 2>/dev/null) || true
  if [ -n "$remote_url" ]; then
    # Strip .git suffix, then extract last path component
    slug="${remote_url%.git}"
    slug="${slug##*/}"
  fi

  if [ -z "${slug:-}" ]; then
    slug=$(basename "$PWD" 2>/dev/null) || true
  fi

  if [ -z "${slug:-}" ]; then
    slug="unknown-project"
  fi

  echo "$slug"
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

# format_timestamp: converts YYYYMMDD-HHMMSS to YYYY-MM-DD HH:MM for display
# Usage: format_timestamp "20260804-143022"
# Returns: "2026-08-04 14:30"
format_timestamp() {
  local ts="$1"
  local date_part="${ts%%-*}"
  local time_part="${ts##*-}"

  # Extract date components
  local year="${date_part:0:4}"
  local month="${date_part:4:2}"
  local day="${date_part:6:2}"

  # Extract time components (only hours and minutes for display)
  local hour="${time_part:0:2}"
  local min="${time_part:2:2}"

  echo "${year}-${month}-${day} ${hour}:${min}"
}

# --- Main Script ---

main() {
  # Exit silently if handoffs directory does not exist (EH-002)
  if [ ! -d "$HANDOFFS_DIR" ]; then
    exit 0
  fi

  local current_slug
  current_slug=$(get_project_slug)

  local current_project_output=""
  local other_projects_output=""
  local found_any=false

  # Scan all project subdirectories
  for project_dir in "$HANDOFFS_DIR"/*/; do
    # Skip if not a directory or if it's the consumed dir at top level
    [ ! -d "$project_dir" ] && continue

    local project_name
    project_name=$(basename "$project_dir")

    # A project literally named "consumed" would collide with the archival directory name
    [ "$project_name" = "consumed" ] && continue

    local project_entries=""

    # Find pending handoff files (not in consumed/)
    for handoff_file in "$project_dir"*.md; do
      # Skip if no matches (glob didn't expand)
      [ ! -f "$handoff_file" ] && continue

      local filename
      filename=$(basename "$handoff_file")

      # Skip empty files (EH-003)
      if [ ! -s "$handoff_file" ]; then
        echo "Warning: Skipping empty handoff file: $handoff_file" >&2
        continue
      fi

      # Extract summary from frontmatter
      local summary
      summary=$(extract_frontmatter_field "$handoff_file" "summary")

      # Skip files with missing frontmatter (EH-003)
      if [ -z "$summary" ]; then
        echo "Warning: Skipping handoff with missing summary: $handoff_file" >&2
        continue
      fi

      # Extract timestamp from filename (strip .md and any collision suffix)
      local ts_raw="${filename%.md}"
      # Remove collision suffixes like -1, -2 (only 1-3 digit suffixes after YYYYMMDD-HHMMSS)
      ts_raw=$(echo "$ts_raw" | sed 's/\([0-9]\{8\}-[0-9]\{6\}\)-[0-9]\{1,3\}$/\1/')
      local display_ts
      display_ts=$(format_timestamp "$ts_raw")

      project_entries="${project_entries}
- [${display_ts}] ${summary}
  Path: ~/.claude/handoffs/${project_name}/${filename}"

      found_any=true
    done

    # Add to appropriate output section
    if [ -n "$project_entries" ]; then
      if [ "$project_name" = "$current_slug" ]; then
        current_project_output="
## ${project_name} (current project)
${project_entries}"
      else
        other_projects_output="${other_projects_output}
## ${project_name}
${project_entries}"
      fi
    fi
  done

  # Exit silently if no pending handoffs found
  if [ "$found_any" = false ]; then
    exit 0
  fi

  # Output the listing in XML-tagged format
  echo "<handoff-pending>"
  echo "Pending session handoffs found:"
  echo "${current_project_output}${other_projects_output}"
  echo ""
  echo 'To pick up a handoff, tell me which one to load (e.g., "load the handoff from Aug 4").'
  echo 'To skip all, say "skip handoffs".'
  echo "</handoff-pending>"
}

# cleanup_consumed: enforces retention limit of 10 consumed handoffs per project
# Deletes the oldest consumed handoffs beyond the limit.
cleanup_consumed() {
  for project_dir in "$HANDOFFS_DIR"/*/; do
    [ ! -d "$project_dir" ] && continue

    local consumed_dir="${project_dir}consumed"
    [ ! -d "$consumed_dir" ] && continue

    local count
    count=$(find "$consumed_dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')

    if [ "$count" -gt 10 ]; then
      local excess=$((count - 10))
      find "$consumed_dir" -maxdepth 1 -name '*.md' -type f -print0 2>/dev/null \
        | sort -z \
        | head -z -n "$excess" \
        | xargs -0 rm -f
    fi
  done
}

# cleanup_pending: enforces retention limit of 20 pending handoffs per project
# Oldest pending handoffs beyond the limit are moved to consumed.
cleanup_pending() {
  for project_dir in "$HANDOFFS_DIR"/*/; do
    [ ! -d "$project_dir" ] && continue

    local count
    count=$(find "$project_dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')

    if [ "$count" -gt 20 ]; then
      local excess=$((count - 20))
      local consumed_dir="${project_dir}consumed"
      mkdir -p "$consumed_dir"
      find "$project_dir" -maxdepth 1 -name '*.md' -type f -print0 2>/dev/null \
        | sort -z \
        | head -z -n "$excess" \
        | xargs -0 -I {} mv {} "$consumed_dir/"
    fi
  done
}

# Run main and cleanup. EH-002 requires the script always exits 0.
# EH-003 warnings go to stderr and are visible to the session.
main "$@" || true
cleanup_pending 2>/dev/null || true
cleanup_consumed 2>/dev/null || true
