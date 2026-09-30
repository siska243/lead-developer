#!/usr/bin/env bash
# Install the commit gate as native git hooks, so commits made by any AI coding
# agent (or by hand) are blocked when tests, lint, secrets or a tracked .env
# fail (pre-commit), or when the message carries an AI attribution (commit-msg).
#
# Usage: bash install-git-hook.sh [PROJECT_DIR] [--uninstall] [--dry-run]
#
# Never overwrites an existing hook or a hook manager (husky, lefthook,
# core.hooksPath): it stops and prints the line to add there instead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

ROOT_ARG="." UNINSTALL=0 DRY=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --uninstall) UNINSTALL=1 ;;
    --dry-run) DRY=1 ;;
    -*) sld_die "unknown option: $arg" ;;
    *) ROOT_ARG="$arg" ;;
  esac
done

git -C "$ROOT_ARG" rev-parse --is-inside-work-tree >/dev/null 2>&1 || sld_die "not a git repository: $ROOT_ARG"
ROOT="$(git -C "$ROOT_ARG" rev-parse --show-toplevel)"
MARKER="# siska-lead-developer commit gate"
GATE="$SCRIPT_DIR/pre-commit-gate.sh"
# Hook name -> command it runs: tests, lint and secrets before the commit, AI attribution check on its message.
LINE_PRE="bash \"$GATE\" \"\$(git rev-parse --show-toplevel)\" </dev/null"
LINE_MSG="bash \"$GATE\" --commit-msg \"\$1\""

hooks_path="$(git -C "$ROOT" config --get core.hooksPath || true)"
if [ -n "$hooks_path" ]; then
  sld_die "core.hooksPath is set ($hooks_path, e.g. husky/lefthook). Add to its pre-commit hook:
  $LINE_PRE
and to its commit-msg hook:
  $LINE_MSG"
fi
HOOKS_DIR="$(git -C "$ROOT" rev-parse --absolute-git-dir)/hooks"

if [ $UNINSTALL -eq 1 ]; then
  for name in pre-commit commit-msg; do
    hook="$HOOKS_DIR/$name"
    if [ -f "$hook" ] && grep -qF "$MARKER" "$hook"; then
      sld_info "remove:  $hook"
      [ $DRY -eq 1 ] || rm "$hook"
    else
      sld_info "skip:    no siska commit gate in $hook"
    fi
  done
  exit 0
fi

# Check both hooks before writing any, so a refusal leaves nothing half-installed.
for name in pre-commit commit-msg; do
  hook="$HOOKS_DIR/$name"
  if [ -f "$hook" ] && ! grep -qF "$MARKER" "$hook"; then
    line="$LINE_PRE"; [ "$name" = commit-msg ] && line="$LINE_MSG"
    sld_die "$hook already exists and is not ours – left untouched. Add this line to it:
  $line"
  fi
done
sld_info "install: $HOOKS_DIR/pre-commit $HOOKS_DIR/commit-msg"
[ $DRY -eq 1 ] && { sld_info "dry run: nothing changed"; exit 0; }
mkdir -p "$HOOKS_DIR"
for name in pre-commit commit-msg; do
  line="$LINE_PRE"; [ "$name" = commit-msg ] && line="$LINE_MSG"
  # If the skill is removed later, warn instead of blocking every commit.
  printf '#!/bin/sh\n%s\n[ -f "%s" ] || { echo "siska commit gate not found: %s (skipped)" >&2; exit 0; }\n%s\n' \
    "$MARKER" "$GATE" "$GATE" "exec $line" >"$HOOKS_DIR/$name"
  chmod +x "$HOOKS_DIR/$name"
done
sld_info "installed. Every commit in $ROOT now runs the gate (bypass: git commit --no-verify, never by an agent)."
