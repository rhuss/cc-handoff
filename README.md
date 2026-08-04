# cc-handoff

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin for session handoffs. Creates structured narrative documents at session end that capture decisions, unfinished work, and subtle context for seamless pickup in future sessions.

## How it works

1. At the end of a session, run `/handoff`
2. The agent reflects on the session and writes a handoff document to `~/.claude/handoffs/<project>/`
3. On first use, a `SessionStart` hook is installed that scans for pending handoffs
4. Next session, pending handoffs are listed automatically and you can load any of them

Handoff documents are organized by project (derived from git remote or directory name) and include YAML frontmatter with project, timestamp, branch, and summary fields.

## Installation

```bash
claude plugin add /path/to/cc-handoff
```

Or add to your `~/.claude/settings.json`:

```json
{
  "plugins": [
    "/path/to/cc-handoff"
  ]
}
```

The `/handoff` slash command is available immediately after installation.

## Usage

### Creating a handoff

```
/handoff
```

The agent writes a markdown document with five sections: Session Summary, Key Decisions, Unfinished Work, Context & Gotchas, and Next Steps.

### Picking up a handoff

When you start a new session, pending handoffs are listed automatically:

```
Pending session handoffs found:

## my-project (current project)
- [2026-08-04 16:07] Built the auth module and fixed edge cases in token refresh
  Path: ~/.claude/handoffs/my-project/20260804-160741.md

To pick up a handoff, tell me which one to load.
To skip all, say "skip handoffs".
```

Say "load the handoff from Aug 4" (or similar) to pick it up. Loaded handoffs are archived to a `consumed/` subdirectory and won't appear again.

## File layout

```
~/.claude/handoffs/
  scan-pending.sh              # SessionStart hook script (auto-installed)
  my-project/
    20260804-160741.md          # Pending handoff
    consumed/
      20260803-091522.md        # Archived (already loaded)
  other-project/
    20260801-143022.md
```

## License

Apache License 2.0
