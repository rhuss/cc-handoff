---
name: handoff
description: Create structured narrative handoff documents at session end for seamless context pickup in future sessions. Captures decisions, unfinished work, and subtle context that would otherwise be lost between sessions.
---

# Session Handoff Skill

Write agent-authored handoff documents that preserve session context across session boundaries. The agent reflects on the session and writes a narrative document capturing what happened, what was decided, what remains unfinished, and any subtle context the next session should know.

## Activation

This skill activates when the user asks to create OR load a handoff.

### Loading triggers (pick up existing handoffs)

Activate on any of these phrases or close variations:
- "load handoff"
- "load latest handoff"
- "load latest"
- "pick up handoff"
- "resume handoff"
- "get handoff"
- "show handoffs"
- "list handoffs"
- "check handoffs"
- "what handoffs are pending"

Also activate when `/handoff --load` or `/handoff --load-latest` is used.

### Creation triggers (write a new handoff)

Activate on any of these phrases or close variations:
- "handoff", "hand off", "create handoff"
- "session summary for next time"
- "save session context for later"
- "wrap up session with notes for the next one"
- "preserve context before ending a session"

Also activate when `/handoff` is used with no arguments.

## Arguments

- **No args**: Create a handoff document for the current session (creation workflow).
- **`--load`**: Load a handoff. Triggers the Loading Handoffs (Interactive Selection) flow. Equivalent to saying "load handoff".
- **`--load-latest`**: Load the most recent handoff for the current project without showing a selection UI. Equivalent to saying "load latest handoff".

## Configuration

Configuration is stored in `~/.claude/handoffs/config.yml`. All keys are optional; the file itself is optional.

### Available keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `max_handoffs` | integer | `5` | Maximum pending handoffs to retain per project. Oldest are pruned after creating a new handoff. Minimum value: 1. |
| `notification` | string | `proactive` | Controls how the SessionStart hook notifies about pending handoffs. |

### Notification modes

The `notification` key accepts one of three values:

- **`proactive`** (default): The SessionStart hook outputs a `<handoff-notify>` block with a directive that tells the agent to proactively mention pending handoffs to the user before responding to their first message.
- **`passive`**: The hook outputs the `<handoff-notify>` block so the agent knows handoffs exist, but without the proactive-mention directive. The agent can reference handoffs if they become relevant but does not interrupt the user.
- **`quiet`**: The hook exits silently with no output. Fully manual mode. The user must explicitly say "load handoff" or use `/handoff --load`.

### Example config.yml

```yaml
max_handoffs: 10
notification: passive
```

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
files:
  - <path/to/file1>
  - <path/to/file2>
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

Collect files that were read, edited, or created during the session for the `files` frontmatter field. Include every file path that was part of the work, not just files that were modified. Use paths relative to the project root. If you are unsure whether a file was involved, include it. The next session needs these paths to locate the work without searching.

**Minimal context sessions**: See the Minimal Context Sessions error handling section below.

### 6. Write the File

Write the complete handoff document to the target path using the Write tool.

### 7. Confirm to the User

After writing, confirm:
- The file path where the handoff was saved
- A brief summary of what was captured (the summary field from frontmatter)

### 8. Retention Cleanup

After writing the new handoff, prune old handoffs to prevent unbounded accumulation.

#### Read Configuration

Read the retention limit from `~/.claude/handoffs/config.yml`:

```bash
config="$HOME/.claude/handoffs/config.yml"
max_handoffs=5

if [ -f "$config" ]; then
  if command -v yq &>/dev/null; then
    val=$(yq -r '.max_handoffs' "$config" 2>/dev/null)
  else
    val=$(grep -E '^max_handoffs:' "$config" 2>/dev/null | sed 's/^max_handoffs:[[:space:]]*//' | tr -d ' ')
  fi

  if [ -n "$val" ] && echo "$val" | grep -qE '^[0-9]+$'; then
    max_handoffs=$val
  elif [ -n "$val" ]; then
    echo "Warning: Invalid max_handoffs value '$val' in config.yml, using default 5" >&2
  fi

  if [ "$max_handoffs" -lt 1 ]; then
    echo "Warning: max_handoffs=$max_handoffs is below minimum, clamping to 1" >&2
    max_handoffs=1
  fi
fi
```

#### Prune Pending Handoffs

Count pending `.md` files for the current project. If the count exceeds `max_handoffs`, delete the oldest files:

```bash
handoff_dir="$HOME/.claude/handoffs/${slug}"
pending_files=$(find "$handoff_dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort)
pending_count=$(echo "$pending_files" | grep -c '.' 2>/dev/null)
pending_count=${pending_count:-0}

if [ "$pending_count" -gt "$max_handoffs" ]; then
  excess=$((pending_count - max_handoffs))
  echo "$pending_files" | head -n "$excess" | while read -r f; do
    rm -f "$f"
  done
fi
```

#### Prune Consumed Directory

Keep at most 10 files in the consumed directory:

```bash
consumed_dir="$HOME/.claude/handoffs/${slug}/consumed"
if [ -d "$consumed_dir" ]; then
  consumed_files=$(find "$consumed_dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort)
  consumed_count=$(echo "$consumed_files" | grep -c '.' 2>/dev/null)
  consumed_count=${consumed_count:-0}

  if [ "$consumed_count" -gt 10 ]; then
    excess=$((consumed_count - 10))
    echo "$consumed_files" | head -n "$excess" | while read -r f; do
      rm -f "$f"
    done
  fi
fi
```

## Handoff Pickup

When the SessionStart hook runs, it checks the `notification` mode in `~/.claude/handoffs/config.yml` (see Configuration above). In `proactive` mode (default), it outputs a `<handoff-notify>` block with a directive for the agent to mention pending handoffs. In `passive` mode, the tag is present but the agent does not proactively announce handoffs. In `quiet` mode, the hook produces no output at all. Regardless of mode, the agent should be ready to help the user load handoffs when asked.

### Loading Handoffs (Interactive Selection)

When the user says "load handoff":

**IMPORTANT: ALWAYS use AskUserQuestion to let the user choose which handoffs to load. NEVER auto-select or auto-load handoffs, even if there is only one available. Do NOT display a table and then load a handoff yourself. The user must explicitly select via AskUserQuestion.**

1. **Scan for pending handoffs**: List all `.md` files (not in `consumed/`) in `~/.claude/handoffs/<current-slug>/` and across all other project directories.

2. **Empty state check**: If no pending handoffs exist for the current project and no cross-project handoffs exist, report "No pending handoffs for this project." and stop.

3. **Build AskUserQuestion options**: Extract the date and `summary` from each pending handoff's frontmatter. Sort by filename (newest first). Build AskUserQuestion options:

   - Show up to 3 most recent **current-project** handoffs as individual options:
     - `label`: Date (Mon DD) + summary snippet (truncated to ~60 chars)
     - `description`: File path (`~/.claude/handoffs/<project>/<filename>`)
   - If more than 3 current-project handoffs exist, OR cross-project handoffs are available, add a 4th option:
     - `label`: "All (N available)" where N = total handoffs across all projects
     - `description`: "Browse all handoffs including other projects"
   - If 3 or fewer current-project handoffs exist and no cross-project handoffs are available, omit the "All" option.
   - Even with a single handoff, present it as an AskUserQuestion option so the user can choose to load or skip it.

4. **Present selection**: Call AskUserQuestion with `multiSelect: true` to let the user choose one or more handoffs. Wait for the user's response before proceeding.

5. **Process selection**: For each selected handoff, follow the "Processing Selected Handoffs" steps below.

### All Projects Expansion

When the user selects "All (N available)":

1. **Scan all project directories**: List all pending `.md` files across all project directories in `~/.claude/handoffs/`.

2. **Build numbered list**: Present a numbered list, current project first, then others grouped by project:

   ```
   Current project (my-project):
     1. [Aug 5] Built the auth module and fixed edge cases
     2. [Aug 4] Refactored the database layer
     3. [Aug 3] Initial project setup

   Other projects:
     other-project:
       4. [Aug 2] Updated deployment scripts
       5. [Aug 1] Fixed CI pipeline
   ```

3. **Accept number-based selection**: Ask the user to enter numbers (e.g., "1, 3, 5") to select handoffs.

4. **Process selection**: For each selected handoff, follow the "Processing Selected Handoffs" steps below.

### Load Latest Shortcut

When the user says "load latest handoff":

1. **Find the most recent handoff**: List `.md` files in `~/.claude/handoffs/<current-slug>/`, sort by filename descending, take the first one.

2. **Empty state check**: If no pending handoffs exist for the current project, report "No pending handoffs for this project." and stop.

3. **Process the handoff**: Follow the "Processing Selected Handoffs" steps for the single most recent handoff. No selection UI is shown.

### Processing Selected Handoffs

For each selected handoff:

1. **Read the handoff file** using the Read tool at the file path.

2. **Internalize the context**: After reading all selected handoffs, naturally reference the handoff content in responses. Use the Key Decisions, Unfinished Work, Context & Gotchas, and Next Steps sections to inform how you approach the user's requests. Do not simply regurgitate the handoff content; weave it into your understanding of the project state.

3. **Cross-project origin**: If a loaded handoff's `project` field in the frontmatter differs from the current project slug, note this to the user: "This handoff originated from the **<project-name>** project."

4. **Archive the handoff**:

   ```bash
   mkdir -p ~/.claude/handoffs/<project-slug>/consumed/
   mv ~/.claude/handoffs/<project-slug>/<timestamp>.md ~/.claude/handoffs/<project-slug>/consumed/<timestamp>.md
   ```

   If the move fails, warn the user but do NOT block the session. The handoff content has already been loaded. The file will appear again in the next session's pending list.

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
