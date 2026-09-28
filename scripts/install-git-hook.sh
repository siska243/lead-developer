#!/usr/bin/env bash
# Install the commit gate as a native git pre-commit hook, so commits made by
# any AI coding agent (or by hand) are blocked when tests, lint, secrets or a
# tracked .env fail check-project.sh.
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
LINE="bash \"$SCRIPT_DIR/pre-commit-gate.sh\" \"\$(git rev-parse --show-toplevel)\" </dev/null"

hooks_path="$(git -C "$ROOT" config --get core.hooksPath || true)"
if [ -n "$hooks_path" ]; then
  sld_die "core.hooksPath is set ($hooks_path, e.g. husky/lefthook). Add this line to its pre-commit hook instead:
  $LINE"
fi
HOOK="$(git -C "$ROOT" rev-parse --absolute-git-dir)/hooks/pre-commit"

if [ $UNINSTALL -eq 1 ]; then
  if [ -f "$HOOK" ] && grep -qF "$MARKER" "$HOOK"; then
    sld_info "remove:  $HOOK"
    [ $DRY -eq 1 ] || rm "$HOOK"
  else
    sld_info "skip:    no siska commit gate in $HOOK"
  fi
  exit 0
fi

if [ -f "$HOOK" ] && ! grep -qF "$MARKER" "$HOOK"; then
  sld_die "$HOOK already exists and is not ours – left untouched. Add this line to it:
  $LINE"
fi
sld_info "install: $HOOK"
[ $DRY -eq 1 ] && { sld_info "dry run: nothing changed"; exit 0; }
mkdir -p "$(dirname "$HOOK")"
GATE="$SCRIPT_DIR/pre-commit-gate.sh"
# If the skill is removed later, warn instead of blocking every commit.
printf '#!/bin/sh\n%s\n[ -f "%s" ] || { echo "siska commit gate not found: %s (skipped)" >&2; exit 0; }\n%s\n' \
  "$MARKER" "$GATE" "$GATE" "exec $LINE" >"$HOOK"
chmod +x "$HOOK"
sld_info "installed. Every commit in $ROOT now runs the gate (bypass: git commit --no-verify, never by an agent)."
