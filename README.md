# cc-handoff

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin for session handoffs. Creates structured narrative documents at session end that capture decisions, unfinished work, and subtle context for seamless pickup in future sessions.

The handoff concept is inspired by Steve Yegge's ["Anti-Clonking Device"](https://yegge.ai/essays/model-welfare) idea: instead of abruptly ending a session and losing context, agents write their own handoff notes that the next session can pick up. As Yegge puts it, "the next day, they're just reading their diary, and with it comes much-needed clarity and continuity."

## How it works

1. At the end of a session, run `/handoff`
2. The agent reflects on the session and writes a handoff document to `~/.claude/handoffs/<project>/`
3. A `SessionStart` hook (registered by the plugin) scans for pending handoffs
4. Next session, you can load any pending handoff when you're ready

Handoff documents are organized by project (derived from git remote or directory name) and include YAML frontmatter with project, timestamp, branch, and summary fields.

## Installation

Clone the repository and install via Make:

```bash
git clone https://github.com/rhuss/cc-handoff.git
cd cc-handoff
make install
```

This registers the local marketplace and installs the handoff plugin into Claude Code.

To verify the plugin is installed:

```bash
claude plugin list
```

### Updating

To update after pulling new changes:

```bash
make reinstall
```

### Uninstalling

```bash
make uninstall
```

### Migrating from previous version

If you installed an earlier version of cc-handoff that used a manual `SessionStart` hook, remove the old hook entry from `~/.claude/settings.json`. Look for and delete the block that references `~/.claude/handoffs/scan-pending.sh`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/handoffs/scan-pending.sh"
          }
        ]
      }
    ]
  }
}
```

The plugin now registers its own `SessionStart` hook automatically, so the manual entry is no longer needed.

## Usage

### Creating a handoff

```
/handoff
```

The agent writes a markdown document with five sections: Session Summary, Key Decisions, Unfinished Work, Context & Gotchas, and Next Steps.

### Picking up a handoff

When you start a new session, a compact notification tells you how many handoffs are available:

```
3 handoffs available (latest: Aug 5). Say "load handoff" to pick one up, or "load latest handoff" to skip selection.
```

You can load handoffs in several ways:

- **"load handoff"** (or `/handoff --load`): presents an interactive selection UI where you can pick one or more handoffs to load
- **"load latest handoff"** (or `/handoff --load-latest`): loads the most recent handoff immediately without any selection prompt
- **"skip handoffs"**: dismisses the notification

Loaded handoffs are archived to a `consumed/` subdirectory and won't appear again.

### Configuration

Create `~/.claude/handoffs/config.yml` to customize behavior:

```yaml
max_handoffs: 5
notification: proactive
auto_handoff: false
```

| Key | Default | Description |
|-----|---------|-------------|
| `max_handoffs` | `5` | Maximum pending handoffs kept per project (minimum 1) |
| `notification` | `proactive` | How the SessionStart hook notifies about pending handoffs |
| `auto_handoff` | `false` | When true, the agent proactively writes draft handoffs during sessions with significant context |

#### Notification modes

| Mode | Behavior |
|------|----------|
| `proactive` | Agent proactively mentions pending handoffs at session start (default) |
| `passive` | Handoff info is available to the agent but it won't interrupt you. You can still say "load handoff" anytime. |
| `quiet` | Hook produces no output. Fully manual: use "load handoff" or `/handoff --load` when you want to check. |

Consumed handoffs are capped at 10 per project. Old handoffs beyond these limits are automatically deleted when you create a new handoff with `/handoff`.

## Directory layout

### Plugin structure (this repository)

```
cc-handoff/
  .claude-plugin/
    marketplace.json          # Local marketplace manifest
  handoff/
    .claude-plugin/
      plugin.json             # Plugin manifest
    hooks.json                # SessionStart hook registration
    scripts/
      get-project-slug.sh    # Shared project slug derivation
      retention-cleanup.sh   # Prunes old handoffs beyond configured limit
      scan-pending.sh        # SessionStart hook that scans for pending handoffs
    skills/
      handoff/
        SKILL.md              # /handoff slash command definition
  Makefile                    # Install/uninstall/validate targets
```

### Handoff storage (created at runtime)

```
~/.claude/handoffs/
  config.yml                          # Optional configuration
  my-project/
    2026-08-04-auth-refactor.md       # Pending handoff
    consumed/
      2026-08-03-initial-setup.md     # Archived (already loaded)
    drafts/                           # Auto-handoff drafts (when auto_handoff: true)
      2026-08-04-debug-session.md     # Draft snapshot
  other-project/
    2026-08-01-ci-pipeline-fix.md
```

## License

Apache License 2.0
