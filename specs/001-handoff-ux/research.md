# Research: Handoff UX Improvements

## R1: YAML Config Parsing in Bash Without yq

**Decision**: Use yq if available, fall back to grep/sed for the single `max_handoffs` key.

**Rationale**: yq is not universally installed. The config file has a single key (`max_handoffs: N`), so a simple grep/sed pattern is sufficient as a fallback. No need for a full YAML parser.

**Implementation**:
```bash
read_max_handoffs() {
  local config="$HOME/.claude/handoffs/config.yml"
  local default=5
  [ ! -f "$config" ] && echo "$default" && return

  local val
  if command -v yq &>/dev/null; then
    val=$(yq -r '.max_handoffs // empty' "$config" 2>/dev/null)
  else
    val=$(grep -E '^max_handoffs:' "$config" 2>/dev/null | sed 's/^max_handoffs:[[:space:]]*//' | tr -d ' ')
  fi

  if [ -z "$val" ] || ! echo "$val" | grep -qE '^[0-9]+$'; then
    [ -n "$val" ] && echo "Warning: Invalid max_handoffs value '$val', using default $default" >&2
    echo "$default"
    return
  fi
  [ "$val" -lt 1 ] && echo "Warning: max_handoffs=$val is below minimum, clamping to 1" >&2 && val=1
  echo "$val"
}
```

**Alternatives considered**: Requiring yq as a dependency (rejected: too heavy for one config key). Using Python for YAML parsing (rejected: unnecessary complexity). Hardcoding the limit (rejected: user configurability is a requirement).

## R2: hookSpecificOutput JSON Format for SessionStart

**Decision**: Use the same JSON structure as the superpowers plugin's SessionStart hook.

**Rationale**: The Claude Code plugin system requires hooks to output JSON with `hookSpecificOutput.additionalContext` for the content to appear in system reminders. Raw stdout is ignored for plugin hooks (unlike settings.json hooks).

**Implementation**: Build the notification string, escape for JSON embedding using bash parameter expansion, output via printf. The `| cat` suffix prevents bash 5.3+ heredoc hangs (same pattern as superpowers).

**Alternatives considered**: Raw text output (rejected: doesn't work for plugin hooks). Using jq to build JSON (rejected: jq may not be installed; the output is simple enough for printf).

## R3: AskUserQuestion Option Limit

**Decision**: Show up to 3 most recent current-project handoffs plus an "All (N available)" option as the 4th choice.

**Rationale**: AskUserQuestion supports max 4 options. With multiSelect enabled, each handoff is an option. The "All" option serves as an overflow mechanism. When selected, the agent prints a full numbered list and accepts number-based selection via free-form text.

**Alternatives considered**: Pagination via multiple AskUserQuestion calls (rejected: awkward UX). Always showing a numbered list (rejected: loses the native selection UI). Using only 2 handoff options + "All" + "Skip" (rejected: wastes slots when most users have <=3 handoffs).

## R4: Retention Cleanup Timing

**Decision**: Run cleanup during `/handoff` creation, after writing the new handoff file.

**Rationale**: Running cleanup at session start would cause surprising file deletions. Running during creation is predictable: the user just created a handoff, so pruning old ones is a natural consequence. The cleanup also handles the consumed directory (limit 10).

**Alternatives considered**: Cleanup at session start (rejected: surprising, slows startup). Cleanup as a separate command (rejected: users would forget to run it). Cleanup on both creation and startup (rejected: unnecessary complexity).
