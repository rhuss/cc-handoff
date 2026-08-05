# Tasks: Handoff UX Improvements

**Input**: Design documents from `/specs/001-handoff-ux/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Tests**: Not explicitly requested. No test tasks included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: User Story 1 - Session Start Notification (Priority: P1) MVP

**Goal**: Replace the full handoff listing output with a compact notification showing count and latest date for the current project only.

**Independent Test**: Create handoff files, start a session. Hook output should be a compact `<handoff-notify>` block under 300 characters, wrapped in hookSpecificOutput JSON.

### Implementation for User Story 1

- [X] T001 [US1] Refactor `main()` in `handoff/scripts/scan-pending.sh` to count current-project handoffs and extract the latest timestamp instead of building full listing strings. **Produces**: `current_count` (integer, number of valid pending .md files for current project) and `latest_ts` (string, YYYYMMDD-HHMMSS of most recent file by filename sort). Remove `current_project_output` and `project_entries` string accumulation for the current project.
- [X] T002 [US1] Refactor `main()` in `handoff/scripts/scan-pending.sh` to count cross-project handoffs (total across all other projects) as a single integer. **Produces**: `cross_count` (integer, sum of valid pending .md files across all non-current project directories). Remove `other_projects_output` string accumulation.
- [X] T003 [US1] Replace the JSON output block in `main()` of `handoff/scripts/scan-pending.sh` to emit a compact `<handoff-notify>` message. Uses variables from T001/T002: `current_count` (integer), `latest_ts` (YYYYMMDD-HHMMSS string), `cross_count` (integer). Three cases: (a) current_count>0: `N handoffs available (latest: Mon DD). Say "load handoff" to pick one up, or "load latest handoff" to skip selection.` with `+M from other projects` suffix when cross_count>0; (b) current_count=0, cross_count>0: `M handoffs available from other projects. Say "load handoff" to browse them.`; (c) both zero: silent exit. Wrap in hookSpecificOutput JSON with a directive for the agent.

**Checkpoint**: At this point, session start shows a compact notification. The full listing is gone.

---

## Phase 2: User Story 2 - Interactive Handoff Selection (Priority: P1)

**Goal**: When the user says "load handoff", present an AskUserQuestion selection UI with current-project handoffs and an "All" option.

**Independent Test**: Have pending handoffs, say "load handoff." Agent should present selection UI with multiSelect, archive loaded handoffs.

### Implementation for User Story 2

- [X] T004 [US2] Replace the "Handoff Pickup" > "Loading a Handoff" section in `handoff/skills/handoff/SKILL.md` with a new flow: when user says "load handoff", scan `~/.claude/handoffs/<current-slug>/` for pending `.md` files, extract date and summary from each, present up to 3 most recent as AskUserQuestion options (multiSelect: true) with "All (N available)" as the 4th option when >3 exist or cross-project handoffs exist. **Empty state**: if no pending handoffs exist for the current project (and no cross-project handoffs), report "No pending handoffs for this project." and stop. Also update the "Handoff Pickup" intro paragraph to recognize `<handoff-notify>` (replacing `<handoff-pending>`) as the hook output tag name
- [X] T005 [US2] Add "All projects" expansion flow to the "Handoff Pickup" section in `handoff/skills/handoff/SKILL.md`: when user selects "All", agent scans all project directories, builds a numbered list (current project first, then others grouped by project), and accepts number-based selection (e.g., "1, 3, 5")
- [X] T006 [US2] Update the "Archiving a Loaded Handoff" section in `handoff/skills/handoff/SKILL.md` to handle multi-select: iterate over all selected handoffs, read each, internalize all, then archive all to consumed/

**Checkpoint**: Users can interactively select and load one or more handoffs.

---

## Phase 3: User Story 3 - Load Latest Shortcut (Priority: P2)

**Goal**: "load latest handoff" loads the most recent current-project handoff without any selection UI.

**Independent Test**: Have multiple handoffs, say "load latest handoff." Most recent is loaded and archived without prompts.

### Implementation for User Story 3

- [X] T007 [US3] Add a "Load Latest Shortcut" subsection to the "Handoff Pickup" section in `handoff/skills/handoff/SKILL.md`: when user says "load latest handoff", find the most recent `.md` file in `~/.claude/handoffs/<current-slug>/` by filename sort, read it, internalize it, archive to consumed/. If no handoffs exist, report "No pending handoffs for this project."

**Checkpoint**: "load latest handoff" works as a single-command shortcut.

---

## Phase 4: User Story 4 - Retention Management (Priority: P2)

**Goal**: Automatically prune old handoffs during `/handoff` creation.

**Independent Test**: Create >5 handoffs, run `/handoff`. Only 5 most recent remain after.

### Implementation for User Story 4

- [X] T008 [US4] Add a "Retention Cleanup" step after step 7 (Confirm to User) in `handoff/skills/handoff/SKILL.md`: after writing the new handoff, count pending `.md` files for the current project, read `max_handoffs` from `~/.claude/handoffs/config.yml` (default 5, minimum 1) using the approach from research.md R1 (yq-then-grep fallback), delete the oldest files beyond the limit. Also enforce the consumed/ directory limit of 10.

**Checkpoint**: Handoff count per project is capped after every `/handoff` invocation.

---

## Phase 5: User Story 5 - Documentation (Priority: P3)

**Goal**: Document the config.yml option and new behavior.

**Independent Test**: Create config.yml with `max_handoffs: 3`, verify cleanup respects it.

### Implementation for User Story 5

- [X] T009 [US5] Update README.md to document the config.yml option and the new compact notification behavior

**Checkpoint**: Configuration is documented and respected by both the script and the skill.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Cleanup and validation

- [X] T010 Remove the `cleanup_pending()` and `cleanup_consumed()` function definitions AND their standalone calls at the bottom of `handoff/scripts/scan-pending.sh` (lines 189-236). Retention now runs during `/handoff` creation via SKILL.md (T008), not at session start. These functions become dead code.
- [X] T011 Run quickstart.md validation scenarios to verify all 5 scenarios pass
- [X] T012 Run `make reinstall` and verify the plugin installs cleanly with the updated script

---

## Dependencies & Execution Order

### Phase Dependencies

- **US1 (Phase 1)**: No dependencies, can start immediately
- **US2 (Phase 2)**: Independent of US1 (different file: SKILL.md vs scan-pending.sh). Can start immediately.
- **US3 (Phase 3)**: Independent of US1/US2. Can start immediately.
- **US4 (Phase 4)**: Independent of US1/US2/US3.
- **US5 (Phase 5)**: Can start after all other phases.
- **Polish (Phase 6)**: Depends on all story phases being complete.

### Parallel Opportunities

- T001 and T002 [US1] can run in parallel (different sections of scan-pending.sh, but same file so sequential is safer)
- T004, T005, T006 [US2] are sequential within SKILL.md
- US1 (scan-pending.sh) and US2/US3/US4 (SKILL.md) touch different files and can proceed in parallel

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: US1 (compact notification)
2. Complete Phase 2: US2 (selection UI)
3. **STOP and VALIDATE**: Test compact notification + interactive selection
4. Reinstall plugin and verify in a fresh session

### Incremental Delivery

1. T001-T003 -> Compact notification works (MVP notification)
2. T004-T006 -> Selection UI works (MVP interaction)
3. T007 -> Load latest shortcut (convenience)
4. T008 -> Retention cleanup (housekeeping)
5. T009 -> Documentation (polish)
6. T010-T012 -> Cleanup and validation

---

## Notes

- Only two source files are modified: `handoff/scripts/scan-pending.sh` and `handoff/skills/handoff/SKILL.md`
- Config file `~/.claude/handoffs/config.yml` is user-created, never shipped or auto-created by the plugin
- The `<handoff-pending>` tag is replaced by `<handoff-notify>` in the hook output
- Commit after each task or logical group
