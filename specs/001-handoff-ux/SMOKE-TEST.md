# Guided Demo Report

**Feature**: Handoff UX Improvements
**Date**: 2026-08-05
**Spec**: specs/001-handoff-ux/spec.md
**Result**: 5 passed, 0 skipped, 0 failed, 0 manual (out of 5)

---

## Triage Summary

| Tier | Count | Detail |
|------|-------|--------|
| full | 3 | All infrastructure available |
| partial | 2 | Proxy evidence with disclaimers |
| setup_offered | 0 | - |
| manual | 0 | - |

User selection: Run everything possible

---

## Flow 1: Compact Notification Output

**Tier**: full
**Covers**: FR-001, FR-002, FR-003, FR-004

### Setup
Created 3 test handoff files for `cc-handoff` project (dates Aug 4 10:00, Aug 4 14:00, Aug 5 16:00). Used existing cross-project handoffs in `openshell-sdk-go` and `personal-skills`.

### Evidence
**Execution**: Ran `scan-pending.sh` in 4 scenarios.

**Scenario 1 (cross-project only)**:
```
2 handoffs available from other projects. Say "load handoff" to browse them.
```

**Scenario 2 (current + cross-project)**:
```
3 handoffs available (latest: Aug 5). +2 from other projects. Say "load handoff" to pick one up, or "load latest handoff" to skip selection.
```

**Scenario 3 (no handoffs)**: Silent exit, empty output, exit code 0.

**Scenario 4 (current only)**:
```
3 handoffs available (latest: Aug 5). Say "load handoff" to pick one up, or "load latest handoff" to skip selection.
```

All outputs wrapped in `hookSpecificOutput` JSON with `hookEventName: "SessionStart"` and `additionalContext` containing `<handoff-notify>` block + agent directive. Notification size: 279 chars (under 300, SC-001).

### Verdict: PASS

All 4 acceptance scenarios produce correct output.

**Verify yourself**:
1. Run `cd <project-root> && bash handoff/scripts/scan-pending.sh`
2. Check output is valid JSON with `hookSpecificOutput.additionalContext` containing `<handoff-notify>`

---

## Flow 2: Interactive Handoff Selection UI

**Tier**: partial
**Covers**: FR-005, FR-006, FR-007

### Setup
Examined SKILL.md for handoff selection UI definitions.

### Evidence
**Execution**: Searched for key instructions matching FR-005, FR-006, FR-007.

**Output**:
- FR-005: Line 207: `Use AskUserQuestion with multiSelect: true`
- FR-006: Lines 199-205: Up to 3 most recent with label/description format, "All (N available)" 4th option logic, omission rule
- FR-007: Line 217: Numbered list expansion, current project first, grouped by project

### Verdict: PASS

All three FRs fully specified in SKILL.md with correct behavior descriptions.

**Partial evidence disclaimer**: Verified SKILL.md instructions, not actual agent interaction. Cannot verify AskUserQuestion behavior in a live session.

**Verify yourself**:
1. Run `rg "multiSelect|All.*available|numbered list" handoff/skills/handoff/SKILL.md`
2. Verify instructions match FR-005, FR-006, FR-007

---

## Flow 3: Load Latest Shortcut

**Tier**: partial
**Covers**: FR-008

### Setup
Examined SKILL.md for "load latest handoff" shortcut path.

### Evidence
**Execution**: Searched for Load Latest Shortcut section and activation triggers.

**Output**:
- Activation: Line 19: `"load latest handoff"` listed as trigger
- Logic: Lines 237-243: Sort by filename descending, take first, no selection UI, empty state check
- Processing: Delegates to "Processing Selected Handoffs" for single most recent file

### Verdict: PASS

Load Latest Shortcut section correctly implements FR-008.

**Partial evidence disclaimer**: Verified SKILL.md instructions, not a live agent session.

**Verify yourself**:
1. Run `rg "Load Latest|load latest" handoff/skills/handoff/SKILL.md`
2. Verify section skips selection UI and loads most recent file

---

## Flow 4: Retention Cleanup

**Tier**: full
**Covers**: FR-009, FR-010, FR-011

### Setup
Created 7 pending handoff files and 12 consumed files for `cc-handoff` project.

### Evidence
**Execution**: Ran retention logic from SKILL.md Step 8 (bash extraction).

**Output**:
- FR-010: 7 pending files pruned to 5. Oldest 2 (`-1000001.md`, `-1000002.md`) deleted, newest 5 kept.
- FR-011: 12 consumed files pruned to 10. Oldest 2 (`-0010000.md`, `-0020000.md`) deleted.
- FR-009: Retention logic confirmed as part of handoff creation workflow (Step 8).

### Verdict: PASS

Both pending and consumed retention correctly identifies excess files, deletes oldest, keeps configured limit.

**Verify yourself**:
1. Create >5 `.md` files in `~/.claude/handoffs/<project>/`, run retention logic, verify only 5 remain
2. Create >10 files in `consumed/`, verify only 10 remain

---

## Flow 5: Configuration Handling

**Tier**: full
**Covers**: FR-012, FR-013, FR-014

### Setup
Created `config.yml` with `max_handoffs: 3` and 7 test handoffs.

### Verdict: PASS (after retry)

**Initial result**: FAIL
**Issue**: `yq -r '.max_handoffs // empty'` uses jq syntax that fails silently with mikefarah/yq v4. Config was ignored, default 5 always used.
**Fix applied**: Changed to `yq -r '.max_handoffs'` in SKILL.md line 129.
**Retry result**: PASS

### Evidence (after fix)
- FR-012: `max_handoffs: 3` correctly read, 7 files pruned to 3.
- FR-013: Missing config defaults to 5, 7 files pruned to 5.
- FR-014: `max_handoffs: 0` clamped to 1 with warning. `max_handoffs: not_a_number` triggers warning, defaults to 5.

**Verify yourself**:
1. Create `~/.claude/handoffs/config.yml` with `max_handoffs: 3`
2. Create >3 handoff files, run retention, verify only 3 remain
3. Delete config.yml, verify default of 5 is used

---

## FR Coverage

| FR | Flow | Verdict | Classification |
|----|------|---------|----------------|
| FR-001 | Flow 1 | PASS | observable (keyword: output) |
| FR-002 | Flow 1 | PASS | observable (keyword: output) |
| FR-003 | Flow 1 | PASS | observable (default - ambiguous) |
| FR-004 | Flow 1 | PASS | observable (default - ambiguous) |
| FR-005 | Flow 2 | PASS | observable (default - ambiguous) |
| FR-006 | Flow 2 | PASS | observable (default - ambiguous) |
| FR-007 | Flow 2 | PASS | observable (default - ambiguous) |
| FR-008 | Flow 3 | PASS | observable (default - ambiguous) |
| FR-009 | Flow 4 | PASS | observable (keyword: write) |
| FR-010 | Flow 4 | PASS | observable (default - ambiguous) |
| FR-011 | Flow 4 | PASS | observable (default - ambiguous) |
| FR-012 | Flow 5 | PASS | observable (keyword: file) |
| FR-013 | Flow 5 | PASS | observable (default - ambiguous) |
| FR-014 | Flow 5 | PASS | observable (default - ambiguous) |
