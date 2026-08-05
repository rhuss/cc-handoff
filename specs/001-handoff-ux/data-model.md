# Data Model: Handoff UX Improvements

## Entities

### Handoff Document

A markdown file with YAML frontmatter. No schema changes from the existing format.

**Location**: `~/.claude/handoffs/<project-slug>/<timestamp>.md`

**Frontmatter fields**:
| Field | Type | Description |
|-------|------|-------------|
| project | string | Project slug (derived from git remote or directory name) |
| timestamp | string | `YYYYMMDD-HHMMSS` format |
| branch | string | Git branch at time of creation, or "none" |
| summary | string | One-line session summary |

**Lifecycle**: pending → consumed → deleted
- **pending**: File exists in project directory (not in consumed/)
- **consumed**: File moved to `<project-slug>/consumed/` after loading
- **deleted**: File removed by retention cleanup

### Config File

**Location**: `~/.claude/handoffs/config.yml`

**Fields**:
| Field | Type | Default | Constraints |
|-------|------|---------|-------------|
| max_handoffs | integer | 5 | Minimum 1. Values < 1 clamped to 1 with stderr warning. |

**Lifecycle**: User-created, user-managed. Never created or modified by the plugin. Read-only access by scan-pending.sh and SKILL.md cleanup logic.

### Project Directory

**Location**: `~/.claude/handoffs/<project-slug>/`

**Contents**:
- `*.md` files (pending handoffs, sorted by filename/timestamp)
- `consumed/` subdirectory (archived handoffs)

**Invariants after cleanup**:
- At most N pending `.md` files (N from config, default 5)
- At most 10 files in `consumed/`

## Relationships

```
~/.claude/handoffs/
├── config.yml                          # Global config (optional)
├── <project-slug-A>/
│   ├── 20260801-091522.md              # Pending handoff
│   ├── 20260804-160741.md              # Pending handoff
│   └── consumed/
│       └── 20260730-143022.md          # Archived handoff
└── <project-slug-B>/
    └── 20260805-094822.md              # Pending handoff
```

## State Transitions

```
[created by /handoff] --> pending
pending --> consumed  (user loads handoff, file moved to consumed/)
pending --> deleted   (retention cleanup: oldest beyond N)
consumed --> deleted  (retention cleanup: oldest beyond 10)
```
