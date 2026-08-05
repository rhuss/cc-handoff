#!/usr/bin/env bash
#
# get-project-slug.sh
#
# Prints the project slug for organizing handoff files.
# Derives from git remote origin URL, falls back to directory name.
#
# This is the canonical slug derivation. Both scan-pending.sh and
# the SKILL.md reference this logic.

set -euo pipefail

slug=""

remote_url=$(git remote get-url origin 2>/dev/null) || true
if [ -n "$remote_url" ]; then
  slug="${remote_url%.git}"
  slug="${slug##*/}"
fi

if [ -z "${slug:-}" ]; then
  slug=$(basename "$PWD" 2>/dev/null) || true
fi

if [ -z "${slug:-}" ]; then
  slug="unknown-project"
fi

echo "$slug"
