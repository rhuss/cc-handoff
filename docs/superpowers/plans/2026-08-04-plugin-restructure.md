# cc-handoff Plugin Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure cc-handoff from a flat skill layout into a proper Claude Code plugin using the nested subdirectory pattern.

**Architecture:** Create `handoff/` plugin source directory with manifests, hooks.json for SessionStart hook registration, and the scanner script as a proper file. Trim the SKILL.md to remove the embedded script and self-install logic. No Python infrastructure needed.

**Tech Stack:** Bash, Claude Code plugin system (marketplace.json, plugin.json, hooks.json)

## Global Constraints

- Plugin name: `handoff`
- Marketplace name: `cc-handoff-marketplace`
- License: Apache-2.0
- No Python dependencies, no venv
- Scanner script output format (`<handoff-pending>` XML block) must not change
- Existing handoff files in `~/.claude/handoffs/` must remain readable

---

### Task 1: Create plugin directory structure and manifest files

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `handoff/.claude-plugin/plugin.json`
- Create: `handoff/hooks.json`

- [ ] **Step 1: Create marketplace manifest at repository root**

```bash
mkdir -p .claude-plugin
```

Write `.claude-plugin/marketplace.json`:

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

- [ ] **Step 2: Create plugin manifest in handoff subdirectory**

```bash
mkdir -p handoff/.claude-plugin
```

Write `handoff/.claude-plugin/plugin.json`:

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

- [ ] **Step 3: Create hooks.json for SessionStart registration**

Write `handoff/hooks.json`:

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

- [ ] **Step 4: Validate both manifests**

Run: `claude plugin validate ./`
Expected: validation passes

Run: `claude plugin validate ./handoff/`
Expected: validation passes

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json handoff/.claude-plugin/plugin.json handoff/hooks.json
git commit -m "feat: add plugin manifests and SessionStart hook registration"
```

### Task 2: Move scanner script and skill into plugin directory

**Files:**
- Move: `scripts/scan-pending-handoffs.sh` -> `handoff/scripts/scan-pending.sh`
- Move: `cc-handoff/skills/handoff/SKILL.md` -> `handoff/skills/handoff/SKILL.md`

- [ ] **Step 1: Move the scanner script**

```bash
mkdir -p handoff/scripts
git mv scripts/scan-pending-handoffs.sh handoff/scripts/scan-pending.sh
rmdir scripts
```

Verify the script is executable:

```bash
chmod +x handoff/scripts/scan-pending.sh
```

- [ ] **Step 2: Move the skill file**

```bash
mkdir -p handoff/skills/handoff
git mv cc-handoff/skills/handoff/SKILL.md handoff/skills/handoff/SKILL.md
```

Clean up the now-empty old directories:

```bash
rmdir cc-handoff/skills/handoff cc-handoff/skills cc-handoff
```

- [ ] **Step 3: Verify scanner script runs without errors**

Run: `bash handoff/scripts/scan-pending.sh`
Expected: Either outputs a `<handoff-pending>` block (if pending handoffs exist) or exits silently with code 0.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: move skill and scanner script into handoff/ plugin directory"
```

### Task 3: Trim SKILL.md to remove embedded script and self-install logic

**Files:**
- Modify: `handoff/skills/handoff/SKILL.md`

The SKILL.md currently has Step 8 ("Install SessionStart Hook") which contains:
- Instructions to check/write `~/.claude/handoffs/scan-pending.sh`
- The entire scanner script embedded as a bash code block (~140 lines)
- Instructions to read/edit `~/.claude/settings.json` to register the hook

All of this is now handled by the plugin's `hooks.json`. Remove it.

- [ ] **Step 1: Remove Step 8 from SKILL.md**

Delete everything from `### 8. Install SessionStart Hook (First Use Only)` through the end of its subsections (up to, but not including, the `## Handoff Pickup` section). This removes:
- The "Steps:" numbered list (steps 1-6 of the self-install)
- The embedded scanner script code block
- The settings.json editing instructions

- [ ] **Step 2: Renumber step 7 confirmation text**

Step 7 ("Confirm to the User") currently says to confirm the file path and summary. This is now the final step of the handoff-writing workflow. No content change needed, just verify it reads cleanly as the last step.

- [ ] **Step 3: Verify the SKILL.md is coherent**

Read through the full file and check:
- Steps 1-7 flow naturally without referencing removed content
- The "Handoff Pickup" section still makes sense (it describes responding to `<handoff-pending>` output, which is now injected by the plugin hook)
- The "Archiving a Loaded Handoff" section is unchanged
- Error handling sections don't reference removed step 8

- [ ] **Step 4: Commit**

```bash
git add handoff/skills/handoff/SKILL.md
git commit -m "refactor: remove embedded scanner script and self-install from SKILL.md"
```

### Task 4: Update .gitignore, add Makefile, update README

**Files:**
- Modify: `.gitignore`
- Create: `Makefile`
- Modify: `README.md`

- [ ] **Step 1: Update .gitignore**

Replace the current `.gitignore` content with:

```gitignore
# Plugin runtime
.claude/settings.local.json
.claude/handoff/

# OS
.DS_Store

# Sensitive
.mcp.json
```

- [ ] **Step 2: Create Makefile**

Write `Makefile` (use tabs for indentation):

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

- [ ] **Step 3: Update README.md**

Replace the current README with updated content reflecting the plugin installation method (`make install`), the new directory layout, and a migration note about removing the old SessionStart hook from `~/.claude/settings.json`.

- [ ] **Step 4: Commit**

```bash
git add .gitignore Makefile README.md
git commit -m "chore: add Makefile, update .gitignore and README for plugin structure"
```

### Task 5: Install and verify the plugin end-to-end

- [ ] **Step 1: Validate manifests**

Run: `make validate`
Expected: Both marketplace and plugin pass validation.

- [ ] **Step 2: Install the plugin**

Run: `make install`
Expected: Marketplace added, plugin installed successfully.

- [ ] **Step 3: Verify the SessionStart hook fires**

Start a new Claude Code session in any project directory. The `<handoff-pending>` block should appear if there are pending handoffs in `~/.claude/handoffs/`, or the session should start silently if there are none.

- [ ] **Step 4: Verify the `/handoff` skill is available**

In a Claude Code session, check that the `handoff` skill appears in the available skills list. Run `/handoff` and confirm it creates a handoff document at `~/.claude/handoffs/<project-slug>/<timestamp>.md`.

- [ ] **Step 5: Clean up old self-installed hook (if present)**

Check `~/.claude/settings.json` for a SessionStart hook referencing `~/.claude/handoffs/scan-pending.sh`. If present, remove it to avoid the scanner running twice.
