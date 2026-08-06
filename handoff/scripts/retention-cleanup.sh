#!/usr/bin/env bash
#
# retention-cleanup.sh
#
# Prunes old handoff files to prevent unbounded accumulation.
# Called after creating a new handoff document.
#
# Usage: retention-cleanup.sh <project-slug>
#
# Reads max_handoffs from ~/.claude/handoffs/config.yml (default: 5).
# Keeps at most max_handoffs pending files and 10 consumed files per project.
#
# Exit codes:
#   0 - always

set -euo pipefail

HANDOFFS_DIR="$HOME/.claude/handoffs"

main() {
  local slug="${1:-}"
  if [ -z "$slug" ]; then
    echo "Usage: retention-cleanup.sh <project-slug>" >&2
    exit 0
  fi

  local config="$HANDOFFS_DIR/config.yml"
  local max_handoffs=5

  if [ -f "$config" ]; then
    local val=""
    if command -v yq &>/dev/null; then
      val=$(yq -r '.max_handoffs' "$config" 2>/dev/null)
    else
      val=$(grep -E '^max_handoffs:' "$config" 2>/dev/null | sed 's/^max_handoffs:[[:space:]]*//' | tr -d ' ')
    fi

    if [ -n "$val" ] && [ "$val" != "null" ] && echo "$val" | grep -qE '^[0-9]+$'; then
      max_handoffs=$val
    elif [ -n "$val" ] && [ "$val" != "null" ]; then
      echo "Warning: Invalid max_handoffs value '$val' in config.yml, using default 5" >&2
    fi

    if [ "$max_handoffs" -lt 1 ]; then
      echo "Warning: max_handoffs=$max_handoffs is below minimum, clamping to 1" >&2
      max_handoffs=1
    fi
  fi

  # Prune pending handoffs
  local handoff_dir="$HANDOFFS_DIR/${slug}"
  if [ -d "$handoff_dir" ]; then
    local pending_files
    pending_files=$(find "$handoff_dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort)
    local pending_count
    pending_count=$(echo "$pending_files" | grep -c '.' 2>/dev/null || echo 0)
    pending_count=${pending_count:-0}

    if [ "$pending_count" -gt "$max_handoffs" ]; then
      local excess=$((pending_count - max_handoffs))
      echo "$pending_files" | head -n "$excess" | while read -r f; do
        rm -f "$f"
      done
    fi
  fi

  # Prune consumed directory (max 10)
  local consumed_dir="$HANDOFFS_DIR/${slug}/consumed"
  if [ -d "$consumed_dir" ]; then
    local consumed_files
    consumed_files=$(find "$consumed_dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort)
    local consumed_count
    consumed_count=$(echo "$consumed_files" | grep -c '.' 2>/dev/null || echo 0)
    consumed_count=${consumed_count:-0}

    if [ "$consumed_count" -gt 10 ]; then
      local excess=$((consumed_count - 10))
      echo "$consumed_files" | head -n "$excess" | while read -r f; do
        rm -f "$f"
      done
    fi
  fi

  # Prune drafts directory (delete stale, cap at 3)
  local drafts_dir="$HANDOFFS_DIR/${slug}/drafts"
  if [ -d "$drafts_dir" ]; then
    find "$drafts_dir" -maxdepth 1 -name '*.md' -type f -mtime +2 -delete 2>/dev/null || true

    local draft_files
    draft_files=$(find "$drafts_dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort -r)
    local draft_count
    draft_count=$(echo "$draft_files" | grep -c '.' 2>/dev/null || echo 0)
    draft_count=${draft_count:-0}

    if [ "$draft_count" -gt 3 ]; then
      local excess=$((draft_count - 3))
      echo "$draft_files" | tail -n "$excess" | while read -r f; do
        rm -f "$f"
      done
    fi
  fi
}

main "$@" || true
