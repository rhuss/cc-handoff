# Implementation Plan: Handoff UX Improvements

**Branch**: `001-handoff-ux` | **Date**: 2026-08-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-handoff-ux/spec.md`

## Summary

Restructure the SessionStart hook to output a compact notification (count + date) instead of full handoff listings. Add progressive disclosure selection UI in the SKILL.md, a "load latest" shortcut, configurable retention management, and cleanup during handoff creation.

## Technical Context

**Language/Version**: Bash (POSIX-compatible with bashisms for parameter expansion), Markdown (SKILL.md)

**Primary Dependencies**: yq (optional, for YAML config parsing), jq (not required), Claude Code plugin system (hookSpecificOutput JSON format)

**Storage**: Filesystem at `~/.claude/handoffs/` (markdown files with YAML frontmatter)

**Testing**: Manual verification via session start and `/handoff` invocation. Script can be tested standalone via `bash scan-pending.sh`.

**Target Platform**: macOS, Linux (wherever Claude Code runs)

**Project Type**: Claude Code plugin (bash scripts + markdown skill definitions)

**Performance Goals**: Hook script completes in under 100ms. Fixed-size output regardless of handoff count.

**Constraints**: AskUserQuestion limited to 4 options (show 3 most recent + "All" option). hookSpecificOutput JSON required for plugin hooks.

**Scale/Scope**: Typical user has 1-10 handoffs across 1-5 projects.

## Global Constraints

- Config file (`~/.claude/handoffs/config.yml`) is read-only for the plugin; never created or modified automatically.
- `yq` is optional; all config reading must fall back to grep/sed (see research.md R1).
- The `<handoff-pending>` tag in hook output is renamed to `<handoff-notify>`. SKILL.md must recognize the new tag.
- Retention cleanup runs only during `/handoff` creation (FR-009), not at session start.

## Constitution Check

Constitution is an unfilled template. No specific gates to check.

## Project Structure

### Documentation (this feature)

```text
specs/001-handoff-ux/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (speckit-tasks)
```

### Source Code (repository root)

```text
handoff/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest (unchanged)
├── hooks.json               # SessionStart hook config (unchanged)
├── scripts/
│   └── scan-pending.sh      # MODIFY: compact notification output, remove cleanup functions
└── skills/
    └── handoff/
        └── SKILL.md         # MODIFY: selection UI, load latest, retention cleanup
```

**Structure Decision**: Existing plugin structure. Two files modified, no new files created (config.yml is user-created, not shipped).

## Complexity Tracking

No constitution violations. No complexity justifications needed.
