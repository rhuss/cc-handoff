# Quickstart Validation: Handoff UX Improvements

## Prerequisites

- Claude Code installed with the handoff plugin (`make install` from cc-handoff repo)
- At least one pending handoff file in `~/.claude/handoffs/`

## Scenario 1: Compact Notification at Session Start

**Setup**:
```bash
mkdir -p ~/.claude/handoffs/test-project/
cat > ~/.claude/handoffs/test-project/20260805-100000.md << 'EOF'
---
project: test-project
timestamp: "20260805-100000"
branch: main
summary: "Test handoff for validation"
---
# Session Summary
Test content.
EOF
```

**Run**: Start a Claude Code session in a directory where `git remote` returns "test-project" (or directory is named "test-project").

**Expected**: System reminder contains a compact `<handoff-notify>` block with count and date, not the full handoff listing. The notification is under 300 characters.

## Scenario 2: Interactive Selection

**Setup**: Same as Scenario 1 (handoff files exist).

**Run**: In the session, say "load handoff".

**Expected**: Agent presents an AskUserQuestion with the handoff(s) listed as selectable options (multiSelect). Selecting one reads the file and moves it to `consumed/`.

## Scenario 3: Load Latest Shortcut

**Setup**: Create 2+ handoff files with different timestamps.

**Run**: Say "load latest handoff".

**Expected**: Agent loads the most recent handoff without showing a selection UI. The loaded file is moved to `consumed/`.

## Scenario 4: Retention Cleanup

**Setup**: Create 7 handoff files for one project in `~/.claude/handoffs/test-project/`.

**Run**: In a session in that project, run `/handoff` to create a new handoff.

**Expected**: After creation, only 5 handoffs remain (the 4 most recent existing ones + the newly created one). The 3 oldest are deleted.

## Scenario 5: Config Override

**Setup**:
```bash
cat > ~/.claude/handoffs/config.yml << 'EOF'
max_handoffs: 3
EOF
```
Create 4 handoff files for a project.

**Run**: Run `/handoff` to create a new handoff.

**Expected**: After creation, only 3 handoffs remain. The config limit of 3 was respected.

## Cleanup

```bash
rm -rf ~/.claude/handoffs/test-project/
rm -f ~/.claude/handoffs/config.yml
```
