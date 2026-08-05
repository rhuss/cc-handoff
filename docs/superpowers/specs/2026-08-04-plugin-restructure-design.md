# cc-handoff Plugin Restructure Design

## Goal

Restructure cc-handoff from a flat skill-with-embedded-script layout into a proper Claude Code plugin following the nested subdirectory pattern used by cc-review, cc-prose, and other sibling plugins.

## Key Decision

The scanner script (`scan-pending.sh`) is currently embedded as a string literal inside the SKILL.md. The agent copies it to `~/.claude/handoffs/scan-pending.sh` on first `/handoff` use and registers a SessionStart hook in `~/.claude/settings.json`. This self-installing behavior is replaced by the plugin's `hooks.json`, which registers the SessionStart hook at plugin install time. The script lives as a proper file in the plugin's `scripts/` directory.

No Python infrastructure is needed. This is a bash-only plugin (one skill, one script), so we skip venv, `run.sh`, `setup_env.sh`, `requirements.txt`, and the `setup-plugin-env` skill entirely.

## Directory Layout

```
cc-handoff/                              # Repository root
├── .claude-plugin/
│   └── marketplace.json                 # Marketplace registry (points to ./handoff)
├── .gitignore                           # Updated with plugin runtime patterns
├── Makefile                             # Lifecycle automation
├── LICENSE                              # Unchanged (Apache-2.0)
├── README.md                            # Updated install instructions
│
├── handoff/                             # Plugin source directory
│   ├── .claude-plugin/
│   │   └── plugin.json                  # Plugin manifest (references hooks.json)
│   ├── hooks.json                       # SessionStart hook registration
│   ├── skills/
│   │   └── handoff/
│   │       └── SKILL.md                 # Trimmed: no embedded script, no self-install
│   └── scripts/
│       └── scan-pending.sh              # Scanner script (formerly embedded + scripts/)
```

### Files Removed

- `cc-handoff/skills/handoff/SKILL.md` (old flat location)
- `scripts/scan-pending-handoffs.sh` (old location, content moves to `handoff/scripts/`)

## Manifest Files

### marketplace.json (repository root)

```json
{
  "name": "cc-handoff-marketplace",
  "owner": {
    "name": "Roland Huss",
    "email": "rhuss@redhat.com"
  },
  "metadata": {
    "description": "Local development marketplace for the cc-handoff plugin."
  },
  "plugins": [
    {
      "name": "handoff",
      "version": "1.0.0",
      "description": "Session handoff documents for seamless context pickup across sessions",
      "author": {
        "name": "Roland Huss",
        "email": "rhuss@redhat.com"
      },
      "source": "./handoff",
      "homepage": "https://github.com/rhuss/cc-handoff",
      "repository": "https://github.com/rhuss/cc-handoff.git"
    }
  ]
}
```

### plugin.json (handoff subdirectory)

```json
{
  "name": "handoff",
  "version": "1.0.0",
  "description": "Session handoff documents for seamless context pickup across sessions",
  "author": {
    "name": "Roland Huss",
    "email": "rhuss@redhat.com"
  },
  "license": "Apache-2.0",
  "repository": "https://github.com/rhuss/cc-handoff",
  "homepage": "https://github.com/rhuss/cc-handoff",
  "keywords": ["claude-code", "plugin", "session-handoff", "context-preservation"],
  "hooks": "./hooks.json"
}
```

### hooks.json

```json
{
  "description": "Session handoff plugin hooks",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/scan-pending.sh"
          }
        ]
      }
    ]
  }
}
```

## SKILL.md Changes

The SKILL.md is trimmed to remove the self-installing hook behavior:

- **Remove step 8 entirely** ("Install SessionStart Hook"). This was ~170 lines of embedded bash script and settings.json editing instructions. The plugin's hooks.json now handles registration.
- **Keep steps 1-7 unchanged**. The handoff-writing workflow (derive slug, generate timestamp, create directory, author document, write file, confirm) is untouched.
- **Keep Handoff Pickup section**. Describes how the agent responds to `<handoff-pending>` hook output.
- **Keep Archiving section**. Move-to-consumed behavior after loading a handoff.
- **Keep all error handling** (EH-001 through Minimal Context Sessions).

## Scanner Script

The file `handoff/scripts/scan-pending.sh` is the existing `scripts/scan-pending-handoffs.sh` renamed. No content changes needed. It already:

- Derives the project slug from git remote or directory name
- Scans `~/.claude/handoffs/*/` for pending `.md` files
- Outputs the `<handoff-pending>` XML block
- Runs cleanup of consumed (>10) and pending (>20) handoffs
- Exits 0 always (never blocks session start)

## Makefile

```makefile
.PHONY: validate install uninstall reinstall help

MARKETPLACE := cc-handoff-marketplace
PLUGIN := handoff@$(MARKETPLACE)

validate:
	claude plugin validate ./
	claude plugin validate ./handoff/

install:
	@claude plugin rm $(PLUGIN) 2>/dev/null || true
	@claude plugin marketplace rm $(MARKETPLACE) 2>/dev/null || true
	@claude plugin marketplace add ./ && echo "Marketplace added."
	claude plugin install $(PLUGIN)

uninstall:
	@echo "Removing plugin..."
	@claude plugin rm $(PLUGIN) 2>/dev/null || echo "Plugin not installed"
	@echo "Removing marketplace..."
	@claude plugin marketplace rm $(MARKETPLACE) 2>/dev/null || echo "Marketplace not installed"

reinstall: uninstall install

help:
	@echo "Available targets:"
	@echo "  validate   - Validate plugin manifests"
	@echo "  install    - Install or update plugin (idempotent)"
	@echo "  uninstall  - Remove plugin and marketplace"
	@echo "  reinstall  - Full reinstall (uninstall + install)"
```

## .gitignore Updates

Add standard plugin runtime patterns:

```gitignore
# Plugin runtime
.claude/settings.local.json
.claude/handoff/

# OS
.DS_Store

# Sensitive
.mcp.json
```

## Migration Notes

Users upgrading from the old self-installed version should:

1. Remove the SessionStart hook entry referencing `~/.claude/handoffs/scan-pending.sh` from `~/.claude/settings.json`
2. Optionally delete `~/.claude/handoffs/scan-pending.sh` (the plugin now runs its own copy)
3. Run `make install` from the repository root

Existing handoff files in `~/.claude/handoffs/` are unaffected. The scanner reads the same directory structure regardless of where it runs from.
