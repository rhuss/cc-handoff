---
name: handoff
description: Create structured narrative handoff documents at session end for seamless context pickup in future sessions. Captures decisions, unfinished work, and subtle context that would otherwise be lost between sessions.
---

# Session Handoff Skill

Write agent-authored handoff documents that preserve session context across session boundaries. The agent reflects on the session and writes a narrative document capturing what happened, what was decided, what remains unfinished, and any subtle context the next session should know.

## Activation

This skill activates when the user asks to:
- Create a handoff or session handoff
- Save session context for later
- "handoff", "hand off", "session summary for next time"
- Wrap up a session with notes for the next one
- Preserve context before ending a session

## Arguments

- **No args**: Create a handoff document for the current session.

## Workflow

### 1. Derive Project Slug

Determine the project identifier for organizing handoff files. This algorithm must match `get_project_slug()` in the scanner script.

```bash
slug=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's|.*/||')
[ -z "$slug" ] && slug=$(basename "$PWD")
[ -z "$slug" ] && slug="unknown-project"
echo "$slug"
```

### 2. Generate Timestamp

```bash
timestamp=$(date +%Y%m%d-%H%M%S)
```

### 3. Create Directory Structure

Create the handoff directory if it does not exist:

```bash
mkdir -p ~/.claude/handoffs/"${slug}"/
```

If `mkdir -p` fails, report the error clearly to the user including the target path and the specific error message, then stop. Do NOT write a partial file.

### 4. Determine Target Path

The handoff file path is: `~/.claude/handoffs/"${slug}"/"${timestamp}".md`

Check if a file already exists at that path (collision). If it does, append a numeric suffix:
- Try `${timestamp}-1.md`, then `${timestamp}-2.md`, and so on until an unused path is found.

### 5. Author the Handoff Document

Write a markdown file with YAML frontmatter and five narrative sections. The agent must author each section with narrative prose, reflecting on the actual session content. Do not use bullet lists; write in flowing paragraphs.

**Document structure:**

```markdown
---
project: <project-slug>
timestamp: "YYYYMMDD-HHMMSS"
branch: <current-git-branch-or-none>
summary: "<one-line summary of the session>"
---

# Session Summary

<What happened this session, the arc of the work, the progression from start to finish>

# Key Decisions

<Decisions made during the session and their reasoning, trade-offs considered>

# Unfinished Work

<What remains to be done, where it was left off, what the next session should pick up>

# Context & Gotchas

<Subtle details, workarounds discovered, things that aren't obvious, traps to avoid>

# Next Steps

<Suggested actions for the next session, in priority order>
```

Get the current git branch for the frontmatter:

```bash
branch=$(git branch --show-current 2>/dev/null || echo "none")
```

**Minimal context sessions**: See the Minimal Context Sessions error handling section below.

### 6. Write the File

Write the complete handoff document to the target path using the Write tool.

### 7. Confirm to the User

After writing, confirm:
- The file path where the handoff was saved
- A brief summary of what was captured (the summary field from frontmatter)

### 8. Install SessionStart Hook (First Use Only)

On every `/handoff` invocation, check whether the SessionStart pickup hook is already installed. If not, install it so that future sessions automatically detect pending handoffs.

**Steps:**

1. **Check if the scanner script exists** at `~/.claude/handoffs/scan-pending.sh`. If it exists, skip to step 3 (hook registration check).

2. **Write the scanner script** to `~/.claude/handoffs/scan-pending.sh` using the Write tool with the content below, then make it executable with `chmod +x ~/.claude/handoffs/scan-pending.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

HANDOFFS_DIR="$HOME/.claude/handoffs"

get_project_slug() {
  local remote_url slug
  remote_url=$(git remote get-url origin 2>/dev/null) || true
  if [ -n "$remote_url" ]; then
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

extract_frontmatter_field() {
  local file="$1" field="$2" value
  value=$(sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null \
    | grep "^${field}:" \
    | head -1 \
    | sed "s/^${field}:[[:space:]]*//" \
    | sed 's/^["'\'']\(.*\)["'\''"]$/\1/' || true)
  echo "$value"
}

format_timestamp() {
  local ts="$1"
  local date_part="${ts%%-*}" time_part="${ts##*-}"
  local year="${date_part:0:4}" month="${date_part:4:2}" day="${date_part:6:2}"
  local hour="${time_part:0:2}" min="${time_part:2:2}"
  echo "${year}-${month}-${day} ${hour}:${min}"
}

main() {
  if [ ! -d "$HANDOFFS_DIR" ]; then
    exit 0
  fi

  local current_slug
  current_slug=$(get_project_slug)

  local current_project_output="" other_projects_output="" found_any=false

  for project_dir in "$HANDOFFS_DIR"/*/; do
    [ ! -d "$project_dir" ] && continue
    local project_name
    project_name=$(basename "$project_dir")
    [ "$project_name" = "consumed" ] && continue

    local project_entries=""
    for handoff_file in "$project_dir"*.md; do
      [ ! -f "$handoff_file" ] && continue
      local filename
      filename=$(basename "$handoff_file")

      if [ ! -s "$handoff_file" ]; then
        echo "Warning: Skipping empty handoff file: $handoff_file" >&2
        continue
      fi

      local summary
      summary=$(extract_frontmatter_field "$handoff_file" "summary")
      if [ -z "$summary" ]; then
        echo "Warning: Skipping handoff with missing summary: $handoff_file" >&2
        continue
      fi

      local ts_raw="${filename%.md}"
      ts_raw=$(echo "$ts_raw" | sed 's/\([0-9]\{8\}-[0-9]\{6\}\)-[0-9]\{1,3\}$/\1/')
      local display_ts
      display_ts=$(format_timestamp "$ts_raw")

      project_entries="${project_entries}
- [${display_ts}] ${summary}
  Path: ~/.claude/handoffs/${project_name}/${filename}"
      found_any=true
    done

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

  if [ "$found_any" = false ]; then
    exit 0
  fi

  echo "<handoff-pending>"
  echo "Pending session handoffs found:"
  echo "${current_project_output}${other_projects_output}"
  echo ""
  echo 'To pick up a handoff, tell me which one to load (e.g., "load the handoff from Aug 4").'
  echo 'To skip all, say "skip handoffs".'
  echo "</handoff-pending>"
}

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
        | sort -z | head -z -n "$excess" | xargs -0 rm -f
    fi
  done
}

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
        | sort -z | head -z -n "$excess" | xargs -0 -I {} mv {} "$consumed_dir/"
    fi
  done
}

main "$@" || true
cleanup_pending 2>/dev/null || true
cleanup_consumed 2>/dev/null || true
```

3. **Read `~/.claude/settings.json`** using the Read tool. If the file does not exist, treat it as `{}`.

4. **Check for existing hook**: Look for a `SessionStart` entry in `hooks` whose `command` contains `scan-pending.sh`. If found, the hook is already installed; skip to confirmation.

5. **Add the hook entry**: If not found, edit `~/.claude/settings.json` to add the SessionStart hook. The target structure is:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "bash ~/.claude/handoffs/scan-pending.sh"
      }
    ]
  }
}
```

Preserve any existing content in settings.json. If `hooks` exists but has no `SessionStart` key, add it. If `hooks.SessionStart` exists as an array, append the new entry. Do not overwrite existing hooks.

6. **Confirm to the user**: "SessionStart pickup hook installed. Future sessions will automatically detect pending handoffs."

If the hook was already present, optionally note: "SessionStart pickup hook is already installed."

## Handoff Pickup

When the SessionStart hook runs, it outputs a `<handoff-pending>` block listing pending handoffs with their paths. The agent should recognize this context and be ready to help the user pick up where a previous session left off.

### Loading a Handoff

When the user asks to load a specific handoff (e.g., "load the handoff from Aug 4" or "pick up the personal-skills handoff"):

1. **Identify the handoff file** from the listing. Match by date, project name, or summary keywords.

2. **Read the full handoff file** using the Read tool at the path shown in the listing (e.g., `~/.claude/handoffs/personal-skills/20260804-143022.md`).

3. **Internalize the context**: After reading, naturally reference the handoff content in responses. Use the Key Decisions, Unfinished Work, Context & Gotchas, and Next Steps sections to inform how you approach the user's requests. Do not simply regurgitate the handoff content; weave it into your understanding of the project state.

4. **Cross-project origin**: If the loaded handoff's `project` field in the frontmatter differs from the current project slug, note this to the user: "This handoff originated from the **<project-name>** project." This helps the user understand the context may reference files or state from a different repository.

### Archiving a Loaded Handoff

After successfully reading and internalizing a handoff, archive it so it does not appear in future session listings:

1. **Create the consumed directory** if it does not exist:

```bash
mkdir -p ~/.claude/handoffs/<project-slug>/consumed/
```

2. **Move the handoff file** to the consumed directory:

```bash
mv ~/.claude/handoffs/<project-slug>/<timestamp>.md ~/.claude/handoffs/<project-slug>/consumed/<timestamp>.md
```

3. **Handle move failures gracefully** (EH-004): If the `mkdir -p` or `mv` command fails, warn the user that the handoff could not be archived but do NOT block the session. The handoff content has already been loaded and remains usable. The file will simply appear again in the next session's pending list.

Only the selected handoff is moved to `consumed/`. Unselected handoffs remain pending for future sessions.

### Skipping Handoffs

If the user says "skip handoffs" or otherwise declines to load any handoff, proceed normally. The pending handoffs remain in place and will be offered again at the next session start.

## Error Handling

### Directory Creation Failure (EH-001)

If `mkdir -p` fails when creating `~/.claude/handoffs/<slug>/`, display an error message that includes:
- The exact target path that could not be created
- The specific error (permission denied, read-only filesystem, etc.)

Do NOT write a partial file. Stop the handoff process and inform the user.

### Permission Errors

If the Write tool fails when writing the handoff document, report:
- The target file path
- The nature of the failure

Do not retry or write to an alternative location. The user needs to resolve the underlying permission issue.

### File Collision Resolution

If the target path `~/.claude/handoffs/<slug>/<timestamp>.md` already exists:
1. Check for `<timestamp>-1.md`
2. If that exists, try `<timestamp>-2.md`
3. Continue incrementing until an unused path is found

This handles the extremely unlikely case of two sessions creating handoffs at the same second.

### Minimal Context Sessions

If the session had no substantive work (no file changes, no decisions, only casual conversation):
- Still create the handoff document
- Note in the Session Summary that minimal context was available
- Populate whatever sections are applicable (even if brief)
- Leave sections like Key Decisions empty with a note like "No significant decisions were made during this session."

## Out of Scope

The following are explicitly not supported by this skill:
- **Multi-machine synchronization**: Handoffs are local to the machine where the session ran. They are not synced across devices.
- **Encryption or access control**: Handoff files are plain markdown with no encryption.
- **Team-based handoffs**: Sharing handoffs between different users is not supported.
- **Integration with external tools**: No integration with task trackers, project management tools, or external services.
- **Handoff editing**: Once created, handoff documents are not intended to be modified.
- **Automatic handoff creation**: Handoffs are only created when the user explicitly invokes `/handoff`.
