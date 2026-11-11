# Brainstorm: General Handoff Sharing

**Date:** 2026-11-11
**Status:** parked

## Intent

Explore sharing handoffs beyond harnesses running on the same machine. The user explicitly parked this topic while prioritizing local interoperability between Claude Code, Codex, and the harness integrations used by cc-review.

## Current Boundary

The current work covers creating and loading handoffs across harnesses on one machine. It does not add synchronization, remote storage, or sharing between users. Local interoperability should preserve portable Markdown documents so a later sharing design can build on them.

## Possible Directions to Explore

These are proposals for a future discussion, not agreed requirements:

- Explicit export and import of individual handoffs or bundles.
- A shared or synchronized directory for one user's machines and remote environments.
- Repository-based exchange for handoffs tied to a project.
- A service or transport adapter for remote retrieval and optional team sharing.

## Questions for a Future Design

- Is the intended recipient the same user on another machine, another agent, or another person?
- How should a project be identified across different clones, paths, forks, and worktrees?
- Does loading consume a handoff globally, or only for a particular recipient?
- How should simultaneous edits, duplicate imports, offline use, and retention interact?
- What information needs redaction before a handoff leaves the local machine?
- Should sharing be explicit per handoff, or automatic for selected projects?

## Next Step

Revisit after local cross-harness support is complete. Choose a concrete sharing workflow before selecting a transport or storage backend.
