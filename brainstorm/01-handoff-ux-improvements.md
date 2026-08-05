# Brainstorm: Handoff UX Improvements

**Date:** 2026-08-05
**Status:** active

## Problem Framing

The current SessionStart hook dumps all handoffs from all projects into the system reminder. This causes three problems:

1. **Scope pollution**: Users see handoffs from unrelated projects, which is distracting. The current project's handoffs are the ones that matter at session start.
2. **System reminder bloat**: Full listings with summaries and paths consume context tokens. With many projects and handoffs, this grows unbounded.
3. **No retention management**: Handoffs accumulate indefinitely. The existing cleanup (20 pending, 10 consumed) is too generous and cleanup only runs during the SessionStart hook, not during handoff creation.
4. **No progressive disclosure**: Everything is shown at once instead of letting the user choose what to see.

## Approaches Considered

### A: Minimal notification with progressive disclosure (chosen)

The SessionStart hook outputs a compact one-line notification (count + latest date for current project only). No summaries, no paths, no full listing in the system reminder. When the user asks to load a handoff, the SKILL.md drives an interactive selection flow using AskUserQuestion. Cleanup happens during `/handoff` creation.

- Pros: Fixed-size hook output regardless of handoff count. Clean separation between notification (hook) and interaction (skill). Scales well.
- Cons: Agent has less context about handoff content at session start. User must explicitly request loading.

### B: Smart summary in notification

Same as A but includes the one-line summary of the latest handoff in the hook output, giving the agent a hint about what happened last session.

- Pros: Agent can reference the latest work without the user explicitly loading.
- Cons: Summary strings can be long. Marginal value since the user will see summaries in the selection UI anyway.

## Decision

Approach A. The hook output stays fixed-size. The selection UI provides the detail when requested.

## Key Requirements

### Hook Output (scan-pending.sh)

- Output only a compact notification for the current project: count + latest date
- If other projects also have handoffs, mention that briefly (e.g., "+3 from other projects")
- Format: `<handoff-notify>2 handoffs available (latest: Aug 5). Say "load handoff" to pick one up, or "load latest handoff" to skip selection.</handoff-notify>`
- Include a directive for the agent to mention this to the user

### Selection UI (SKILL.md Handoff Pickup)

- "load handoff" triggers an AskUserQuestion with multiSelect: true
- Options: each current-project handoff (label: date + summary snippet, description: path), plus an "All projects" option
- If "All projects" selected, show a numbered list of all handoffs across all projects, allow selecting by number(s)
- "load latest handoff" shortcut: skip selection, load the most recent handoff for current project
- Multi-select allowed: user can load several handoffs at once
- After loading, archive selected handoffs to consumed/

### Retention and Cleanup

- Keep at most N latest pending handoffs per project (default: 5)
- Cleanup runs during `/handoff` creation (after writing the new handoff, prune oldest beyond N)
- Consumed directory limit stays at 10 (existing behavior)
- N is configurable via `~/.claude/handoffs/config.yml` with key `max_handoffs: 5`

### Config

- Location: `~/.claude/handoffs/config.yml`
- Initial schema: just `max_handoffs: 5`
- Script reads config if present, falls back to default if missing

## Open Questions

- Should the "All projects" view also use AskUserQuestion (limited to 4 options), or a free-form numbered list? With many projects, AskUserQuestion hits the option limit. A numbered list printed by the agent is more flexible.
- Should cleanup also run during the SessionStart hook scan, or only during `/handoff` creation? Running during creation is simpler and avoids surprising file deletions at session start.
