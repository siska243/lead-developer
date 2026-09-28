#!/usr/bin/env bash
# Commit gate for AI coding agents (Claude Code PreToolUse hook on "git commit").
#
# Reads the hook JSON on stdin, runs check-project.sh --run-tests --run-lint in
# the session directory, and blocks the commit (exit 2, reason on stderr) when
# a test, a lint, a secret or a tracked .env fails the check.
# Can also be run by hand: bash pre-commit-gate.sh [PROJECT_DIR] </dev/null
# Skip (user decision only): SISKA_SKIP_GATE=1 git commit … (or --no-verify for the git hook).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input=""
[ -t 0 ] || input="$(cat)"
# Hook mode: only act on git commits, including "git -C dir commit" and "git -c k=v commit".
if [ -n "$input" ] && ! printf '%s' "$input" | grep -Eq 'git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+commit([^[:alnum:]-]|$)'; then
  exit 0
fi

# Explicit skip, visible in the command or the environment.
if [ "${SISKA_SKIP_GATE:-}" = 1 ] || printf '%s' "$input" | grep -Eq 'SISKA_SKIP_GATE=1[[:space:]]+git'; then
  echo "siska commit gate skipped (SISKA_SKIP_GATE=1): tests, lint and secret checks were NOT run." >&2
  exit 0
fi

# "cwd" from the hook payload; fall back to the argument or the current directory.
dir="$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
dir="${dir:-${1:-$PWD}}"

# Only guard git repositories.
git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
root="$(git -C "$dir" rev-parse --show-toplevel)"

# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
if [ "$(sld_setting "$root" commit-gate)" = off ]; then
  echo "siska commit gate is OFF (settings): tests, lint and secret checks were NOT run. Turn it back on: settings gate on." >&2
  exit 0
fi

if report="$(bash "$SCRIPT_DIR/check-project.sh" "$root" --run-tests --run-lint 2>&1)"; then
  exit 0
fi

{
  echo "Commit blocked by siska-lead-developer: the pre-commit check failed. Fix these problems, re-run the check (check-code command, or check-project.sh --run-tests --run-lint), then commit again."
  printf '%s\n' "$report" | grep -E '^(BLOCK|RESULT)|failed|possible secret' | head -n 40
} >&2
exit 2
