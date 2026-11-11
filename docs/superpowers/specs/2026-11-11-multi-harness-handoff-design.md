# Multi-Harness Handoffs on One Machine

Date: 2026-11-11

Status: proposed; awaiting user approval

## Intent and agreed scope

Make cc-handoff available in the same way as the sibling cc-review plugin:
one distributable containing a shared core, thin Claude Code and Codex skill
wrappers, and an OpenCode command adapter. A user can create a handoff in
Claude Code and load it in Codex, or do the reverse, on the same machine.
The document and its lifecycle belong to the project rather than a harness.

The user chose a neutral shared directory with backward compatibility.
Sharing across machines and remote environments is parked separately in
`brainstorm/02-general-handoff-sharing.md`.

## Goals

- Support creation, listing, interactive loading, and loading the latest handoff
  through all three harness integrations.
- Use `~/.cc-handoff/` for new documents, drafts, and configuration.
- Discover existing documents in `~/.claude/handoffs/` without requiring a
  migration or modifying the user's existing installation settings.
- Preserve narrative Markdown, project grouping, cross-project browsing,
  archiving after loading, retention settings, and optional drafts.
- Keep workflow rules and storage resolution in one shared implementation.
- Document the available notification behavior for each harness accurately.

## Non-goals and anti-goals

No remote storage, synchronization, team sharing, export/import, or new spec-kit
extension. No transcript conversion or automatic transfer of live session state.
No automatic loading merely because another harness created a handoff.
Do not split shared storage into per-harness queues, silently move the legacy
directory, edit users' global agent instructions, or require a new runtime just
to support multiple harnesses.

## Constraints and existing behavior

The plugin currently comprises one substantial skill, three Bash scripts, and a
Claude Code SessionStart hook. It has no automated test suite. Documents already
have a portable Markdown body and YAML frontmatter. Paths, environment variables,
question tools, and hook output are currently specific to Claude Code.

The sibling cc-review provides the packaging reference. Follow its structural
pattern rather than copying its review-specific workflow or dependencies.
The existing plugin name `handoff` and marketplace name
`cc-handoff-marketplace` remain stable.

## Approaches

1. **Neutral shared directory with legacy discovery (selected).** Write to
   `~/.cc-handoff/`; read both it and `~/.claude/handoffs/`. This provides a clear
   shared home and preserves existing handoffs, at the cost of a small amount
   of compatibility logic. The user selected this approach.
2. **Use the existing Claude directory for every harness.** This avoids storage
   changes but permanently couples shared data and configuration to a
   Claude-specific location. It was considered and not selected.

Both use cc-review's shared-core packaging. Per-harness copies of the workflow
are unsuitable because they would drift and fragment the handoff lifecycle.

## Distribution and adapters

The `handoff/` directory remains the distributable:

```text
handoff/
  .claude-plugin/plugin.json
  .codex-plugin/plugin.json
  skills/handoff/SKILL.md
  opencode/
    command/handoff.md
    install.sh
  core/
    commands/handoff.md
    scripts/
      ...shared storage, project, scanning, and retention helpers...
  hooks.json
  scripts/
    ...Claude hook adapter and any compatibility entry points...
```

Skill and command wrappers resolve the installed core, pass through arguments
and the natural-language intent, and delegate. Resolve from the wrapper's known
installation location first, with `.cc-handoff/core` in the project and
`~/.cc-handoff/core` as explicit fallback locations, following cc-review.
For OpenCode, honor the installed `.core-path` pointer written by its installer.
Failure to resolve the core produces a useful installation error.

No shared command relies on `CLAUDE_PLUGIN_ROOT`. Its absolute core path must
be supplied in every shell block, since shell variables do not persist between
tool calls. Use the current harness's file-reading, file-writing, shell, and
question facilities rather than prescribing Claude tool names.

The OpenCode installer follows cc-review's project-local command installation
pattern and validates that the recorded core exists. It changes only the
requested project's integration files, not global settings.

Keep the existing Claude installation shortcut working. Document native Codex
installation and the OpenCode installer alongside it. Validate both manifests
and keep release metadata consistent across manifests and marketplace entries.

## Shared storage and compatibility

These detailed compatibility choices are proposals made by the assistant:

- New pending documents: `~/.cc-handoff/<project>/*.md`.
- New drafts: `~/.cc-handoff/<project>/drafts/*.md`.
- Archived documents: the originating project's `consumed/` directory in the
  same storage root as the pending document.
- Active configuration: `~/.cc-handoff/config.yml` if present; otherwise
  `~/.claude/handoffs/config.yml` if present; otherwise existing defaults.
  Select one whole configuration file; do not merge keys between files.
- Discover pending documents in both storage roots for every harness. Do not
  copy, migrate, rewrite, or discard legacy documents during discovery.
- If the two roots resolve to the same physical directory, scan it once.
  Otherwise, separate files are separate handoffs, even if their names match;
  listings retain the full source path so either can be selected.
- Keep legacy date-only, date-plus-topic, and numeric timestamp filenames
  readable. For latest selection and retention, use a valid frontmatter
  timestamp when available, fall back to a parseable filename timestamp, then
  file modification time. Resolve ties deterministically by full path.
- Preserve the current project-slug algorithm in a shared helper, so existing
  handoffs and different harnesses agree. Improving project identity across
  unrelated repositories with the same name is deferred.
- Run configured retention after creating a handoff for the destination root;
  do not prune legacy storage merely because new storage is being used.
  Apply the consumed limit to the originating archive after a successful load,
  including immediate deletion for `max_consumed: 0`.

Retain the current configuration keys and defaults: `max_handoffs: 5`,
`max_consumed: 10`, `notification: proactive`, and `auto_handoff: false`.
Preserve the documented special values and minimums.

## Document contract

Retain the five narrative sections and existing frontmatter fields: project,
timestamp, branch, summary, and optional files and auto. New documents may add
an informational `harness` field (`claude-code`, `codex`, or `opencode`);
documents without it are valid. Harness origin must never filter discoverability
or control which harness can load a document.

Generate new timestamps consistently with seconds and a timezone offset, while
accepting the historical formats. Keep semantic filenames and numeric suffixes
for collisions. Do not overwrite an existing pending, draft, or archived file.

Loaded handoffs provide prior-session context. Follow the active session's user
instructions and permissions when acting on their suggested next steps.

## User workflow

Support the existing natural-language triggers and arguments in every wrapper:
no arguments creates a handoff, `--load` opens selection, and `--load-latest`
loads the latest pending document for the current project across both roots.
Document invocation syntax separately for each harness.

Interactive loading shows recent current-project handoffs first, with a way to
browse all projects. Use a suitable question tool when available. If it is absent
or lacks multiple selection, show a numbered list and accept explicit numbers
or paths in the conversation. Always wait for a selection; a single available
handoff does not imply consent to load. The explicit latest shortcut needs no
selection prompt.

Read selected files fully before archiving them. Mention a different source
project when applicable. Archive in the file's source root with collision-safe
naming. A file loaded and archived in Codex is consequently no longer pending
in Claude Code, and vice versa. If archiving fails, preserve the source, report
that it may appear again, and keep the already loaded context available.
Independent copies of a file are not synchronized; cross-machine deduplication
is outside this design.

## Notifications and drafts

Separate shared discovery from the hook's output format. Keep the Claude Code
SessionStart adapter and its compact notification behavior. It must scan both
roots, use the shared configuration rules, and remain nonblocking on errors.

Do not assume that Claude's hook registration or JSON is supported by another
harness. Codex and OpenCode must support discovery when the user invokes the
handoff skill or command. Native automatic startup integration is included only
where the existing integration mechanisms support it without global instruction
edits; unsupported automatic notification is documented plainly. Shared scanning
must also be usable without producing Claude-specific output.

Keep optional drafts as part of the shared command. New drafts use the neutral
root; explicit finalization can use drafts from either root as context. Delete
only the drafts actually incorporated after the final handoff has been saved.
Keep existing promotion behavior for leftover drafts at Claude session start.
Other harnesses perform that discovery/promotion when the user explicitly loads
or lists handoffs. Promotion must preserve the source root and avoid overwrite.
This change does not promise live session detection or automatic draft writing
before the skill has made its instructions available to the agent.

## Verification and acceptance

Add focused automated tests using temporary home directories and fixture files;
tests must never read or mutate the user's real handoffs or installations.

- A handoff marked as created by Claude Code is discoverable and loadable by
  the Codex integration, and the reverse works with the same file contract.
- Both adapters delegate to the same command; manifests and core paths resolve
  from installation locations outside the source checkout.
- Pending files from both roots are listed; consumed files and drafts do not
  appear as pending before deliberate promotion.
- Loading archives in the originating root, making the document disappear from
  every harness's pending scan. Archive collisions preserve both documents.
- Configuration precedence, missing configuration, legacy formats, new timestamp
  ordering, and root aliases behave as described.
- Retention and draft promotion respect their root boundaries and collision
  rules, with coverage for the existing special retention values.
- Claude hook output remains valid and nonblocking; plain scanning is reusable.
- The OpenCode installer records a usable absolute core path and can be rerun.

Run the repository's manifest validation when the necessary CLI is installed,
plus shell syntax checks and the new focused test suite. Provide a manual
two-direction Claude Code/Codex smoke test. State clearly if full interactive
sessions in those harnesses were not exercised.

## Left to the builder

Choose helper file boundaries, internal discovery output format, fixture/test
runner details, and compatibility wrapper names. Keep the implementation within
the existing Bash/Markdown stack unless a concrete verified requirement makes
that impractical. Verify current native integration capabilities before claiming
automatic startup behavior. No additional sharing transport is authorized.
