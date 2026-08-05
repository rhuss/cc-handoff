# Feature Specification: Handoff UX Improvements

**Feature Branch**: `001-handoff-ux`

**Created**: 2026-08-05

**Status**: Draft

**Input**: Restructure SessionStart hook for compact notification, add progressive disclosure selection UI, add retention management, add config support.

## User Scenarios & Testing

### User Story 1 - Session Start Notification (Priority: P1)

A user starts a new Claude Code session in a project that has pending handoff documents. Instead of seeing a full listing of all handoffs from all projects dumped into the context, the user sees a compact one-line notification mentioning how many handoffs are available for the current project and the date of the most recent one. The notification also mentions if other projects have handoffs available.

**Why this priority**: This is the core UX improvement. Every session start is affected, and reducing system reminder bloat directly improves context utilization.

**Independent Test**: Can be tested by creating handoff files in `~/.claude/handoffs/<project>/` and starting a session. The hook output should be a compact JSON notification, not a full listing.

**Acceptance Scenarios**:

1. **Given** a project with 3 pending handoffs (latest from Aug 5), **When** a session starts, **Then** the hook outputs `<handoff-notify>3 handoffs available (latest: Aug 5). Say "load handoff" to pick one up, or "load latest handoff" to skip selection.</handoff-notify>` wrapped in hookSpecificOutput JSON.
2. **Given** a project with 2 pending handoffs and 3 handoffs in other projects, **When** a session starts, **Then** the notification includes "+3 from other projects" in addition to the current project count.
3. **Given** a project with no pending handoffs but other projects have handoffs, **When** a session starts, **Then** the notification mentions only the cross-project handoffs (e.g., "3 handoffs available from other projects").
4. **Given** no pending handoffs anywhere, **When** a session starts, **Then** no output is produced (silent exit).

---

### User Story 2 - Interactive Handoff Selection (Priority: P1)

A user says "load handoff" after seeing the startup notification. The agent presents an interactive selection using AskUserQuestion with current-project handoffs listed (multiSelect enabled), plus an "All (N available)" option when more than 3 exist. The user can select one or more handoffs to load. Each selected handoff is read, internalized by the agent, and archived to the consumed directory.

**Why this priority**: This is the primary interaction path for loading handoffs. Without it, the compact notification is useless.

**Independent Test**: Can be tested by having pending handoffs and asking "load handoff." The agent should present a selection UI, allow multi-select, and archive loaded handoffs.

**Acceptance Scenarios**:

1. **Given** 3 current-project handoffs, **When** the user says "load handoff", **Then** the agent presents an AskUserQuestion with multiSelect: true, listing up to 3 most recent handoffs with date and summary snippet as label, file path as description. If no cross-project handoffs exist and ≤3 current-project handoffs exist, the "All" option is omitted.
2. **Given** the user selects 2 of 3 handoffs, **When** selections are confirmed, **Then** the agent reads both files, internalizes the content, and moves both to the consumed directory.
3. **Given** 5 current-project handoffs and 3 cross-project handoffs, **When** the user says "load handoff", **Then** the 4th option is "All (8 available)". Selecting it presents a numbered list of all handoffs (current project first, then others grouped by project), allowing selection by number (e.g., "1, 3, 5").

---

### User Story 3 - Load Latest Shortcut (Priority: P2)

A user says "load latest handoff" to skip the selection process entirely. The agent loads the most recent handoff for the current project without presenting any selection UI.

**Why this priority**: Convenience shortcut for the common case where the user just wants to pick up where they left off.

**Independent Test**: Can be tested by having multiple handoffs and saying "load latest handoff." The most recent should be loaded and archived without any selection prompt.

**Acceptance Scenarios**:

1. **Given** 3 current-project handoffs with timestamps 10:00, 14:00, 16:00, **When** the user says "load latest handoff", **Then** the agent reads the 16:00 handoff, internalizes it, and archives it to consumed.
2. **Given** no current-project handoffs, **When** the user says "load latest handoff", **Then** the agent reports that no handoffs are available for the current project.

---

### User Story 4 - Retention Management (Priority: P2)

When a user creates a new handoff with `/handoff`, the system automatically prunes old handoffs for the current project, keeping only the N most recent (default 5). The consumed directory is also pruned to keep at most 10.

**Why this priority**: Prevents unbounded accumulation without requiring manual cleanup.

**Independent Test**: Can be tested by creating more than 5 handoffs for a project, then running `/handoff`. Only the 5 most recent should remain; older ones should be deleted.

**Acceptance Scenarios**:

1. **Given** a project with 6 pending handoffs and max_handoffs=5, **When** the user runs `/handoff` and a new handoff is created, **Then** the oldest 2 handoffs are deleted (keeping 5 most recent, which includes the newly created one).
2. **Given** max_handoffs is set to 3 in config.yml, **When** a new handoff is created for a project with 4 existing handoffs, **Then** the oldest 2 are deleted (keeping 3 including the new one).
3. **Given** no config.yml exists, **When** cleanup runs, **Then** the default limit of 5 is used.

---

### User Story 5 - Configuration (Priority: P3)

A user creates `~/.claude/handoffs/config.yml` to customize the retention limit. The scanner script and handoff creation skill both read this config.

**Why this priority**: Configuration is a quality-of-life feature. The defaults work without it.

**Independent Test**: Can be tested by creating config.yml with `max_handoffs: 3` and verifying that cleanup respects the configured limit.

**Acceptance Scenarios**:

1. **Given** `~/.claude/handoffs/config.yml` contains `max_handoffs: 3`, **When** cleanup runs, **Then** only 3 handoffs are kept per project.
2. **Given** `~/.claude/handoffs/config.yml` does not exist, **When** cleanup runs, **Then** the default of 5 is used.
3. **Given** `~/.claude/handoffs/config.yml` contains invalid YAML, **When** cleanup runs, **Then** the default of 5 is used and a warning is logged to stderr.

---

### Edge Cases

- What happens when the handoffs directory does not exist? Silent exit, no output.
- What happens when a handoff file has no summary in frontmatter? Skip it with a stderr warning.
- What happens when the user says "load handoff" but there are no handoffs? The agent reports "No pending handoffs for this project."
- What happens when all handoffs are from other projects (none for current)? The notification mentions only cross-project handoffs.
- What happens when config.yml sets max_handoffs to 0 or a negative number? Clamp to 1 (the minimum per FR-014) and log a warning to stderr about the misconfigured value.
- What happens when moving a handoff to consumed/ fails (permissions, disk full)? Log a warning to stderr but continue processing remaining handoffs. The handoff stays in the pending directory and will appear again at next session start.
- What happens when the consumed/ directory does not exist? Create it automatically before moving files.

## Clarifications

### Session 2026-08-05

- Q: How should handoff selection handle the AskUserQuestion 4-option limit when a project has more than 3 pending handoffs? → A: Show the 3 most recent handoffs as individual options, plus "All (N available)" as the 4th option. Selecting "All" presents the complete list for number-based selection.

## Requirements

### Functional Requirements

- **FR-001**: The SessionStart hook script MUST output a compact notification containing only the count and latest date for the current project, not full handoff listings.
- **FR-002**: The notification MUST be wrapped in hookSpecificOutput JSON format with `hookEventName: "SessionStart"` and `additionalContext` containing the `<handoff-notify>` block.
- **FR-003**: The notification MUST include a directive instructing the agent to mention pending handoffs to the user.
- **FR-004**: The notification MUST mention cross-project handoffs if they exist (e.g., "+N from other projects").
- **FR-005**: The SKILL.md MUST define a "Handoff Pickup" flow that uses AskUserQuestion with multiSelect: true for current-project handoff selection.
- **FR-006**: The selection options MUST show up to 3 most recent current-project handoffs (label: date + summary, description: path). When more than 3 current-project handoffs exist or cross-project handoffs are available, an "All (N available)" option MUST appear as the 4th choice (where N = total handoffs across all projects). When ≤3 current-project handoffs exist and no cross-project handoffs are available, the "All" option is omitted.
- **FR-007**: When "All (N available)" is selected, the agent MUST present a numbered list of all handoffs (current project first, then others grouped by project), allowing selection by number.
- **FR-008**: The SKILL.md MUST support a "load latest handoff" shortcut that loads the most recent handoff for the current project without selection UI.
- **FR-009**: Retention cleanup MUST run during `/handoff` creation, after writing the new handoff file.
- **FR-010**: Retention MUST keep at most N pending handoffs per project (default: 5), deleting the oldest beyond the limit.
- **FR-011**: Consumed directory retention MUST keep at most 10 files per project, deleting the oldest beyond the limit.
- **FR-012**: The retention limit N MUST be configurable via `~/.claude/handoffs/config.yml` with key `max_handoffs`.
- **FR-013**: If config.yml is missing or unparseable, the default limit of 5 MUST be used.
- **FR-014**: The minimum value for max_handoffs MUST be 1.

### Key Entities

- **Handoff document**: A markdown file with YAML frontmatter (project, timestamp, branch, summary) and five narrative sections. Stored at `~/.claude/handoffs/<project-slug>/<timestamp>.md`.
- **Config file**: A YAML file at `~/.claude/handoffs/config.yml` containing `max_handoffs: N`.
- **Consumed directory**: Per-project archive at `~/.claude/handoffs/<project-slug>/consumed/` for loaded handoffs.

## Success Criteria

### Measurable Outcomes

- **SC-001**: The SessionStart hook output is a fixed-size notification (under 300 characters) regardless of how many handoffs exist.
- **SC-002**: Users can load a specific handoff within 2 interactions (notification seen, selection made).
- **SC-003**: Users can load the most recent handoff in 1 interaction ("load latest handoff").
- **SC-004**: Pending handoff count per project never exceeds the configured limit after any `/handoff` invocation.
- **SC-005**: System reminder token consumption from handoff context is reduced by 90%+ compared to the current full-listing approach.

## Assumptions

- The project slug derivation algorithm (git remote or directory name) is reliable for identifying the current project. No changes to slug derivation are in scope.
- The `yq` command is available on the user's system for YAML parsing in the shell script. If not available, the script falls back to grep/sed-based parsing or the default value.
- The AskUserQuestion tool supports multiSelect and is available in all Claude Code environments where the plugin runs.
- Handoff documents continue to use the existing YAML frontmatter format with `summary` and `timestamp` fields.
