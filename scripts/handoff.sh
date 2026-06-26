#!/usr/bin/env bash
#
# HANDOFF move of the dependency-hygiene loop (bash / Linux / macOS / Git Bash).
#
# Creates or tears down a dedicated git worktree per finding so parallel bump
# attempts never collide on package.json / package-lock.json. Each finding gets
# its own branch fix/<slug> checked out in its own directory.
#
# Usage:
#   scripts/handoff.sh create   <slug>
#   scripts/handoff.sh teardown <slug>
#
# Example:
#   scripts/handoff.sh create   lodash-4.17.15-to-4.17.21
#   scripts/handoff.sh teardown lodash-4.17.15-to-4.17.21

set -euo pipefail

ACTION="${1:-}"
SLUG="${2:-}"

if [[ -z "$ACTION" || -z "$SLUG" ]]; then
  echo "usage: handoff.sh <create|teardown> <slug>" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Worktrees live OUTSIDE the working tree (a sibling dir) so they can never be
# accidentally committed into the repo they are bumping.
WORKTREES_ROOT="$(cd "$REPO_ROOT/.." && pwd)/dep-hygiene-loop-worktrees"
WORKTREE_PATH="$WORKTREES_ROOT/$SLUG"
BRANCH="fix/$SLUG"

cd "$REPO_ROOT"

case "$ACTION" in
  create)
    mkdir -p "$WORKTREES_ROOT"
    echo "Creating worktree '$WORKTREE_PATH' on branch '$BRANCH'..."
    git worktree add -b "$BRANCH" "$WORKTREE_PATH" HEAD
    echo "Worktree ready. Apply the bump INSIDE: $WORKTREE_PATH"
    echo "goal=all tests pass and lint is clean, advisory resolved for this package"
    ;;
  teardown)
    echo "Tearing down worktree '$WORKTREE_PATH' and branch '$BRANCH'..."
    if [[ -d "$WORKTREE_PATH" ]]; then
      git worktree remove "$WORKTREE_PATH" --force
    fi
    git worktree prune
    git branch -D "$BRANCH" 2>/dev/null || true
    echo "Teardown complete."
    ;;
  *)
    echo "unknown action: $ACTION (expected create|teardown)" >&2
    exit 2
    ;;
esac
