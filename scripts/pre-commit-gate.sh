#!/usr/bin/env bash
# Commit gate for AI coding agents (Claude Code PreToolUse hook on "git commit").
#
# Reads the hook JSON on stdin and, in the session directory:
#   1. refuses an AI attribution (AI co-author trailer, "Generated with <AI tool>")
#      in a commit message or pull request text – always;
#   2. runs secret-scan.sh (hardcoded passwords, keys, tokens, sensitive files,
#      tracked .env) – always, even when the gate is off or skipped;
#   3. runs check-project.sh --run-tests --run-lint.
# Blocks with exit 2 and the reason on stderr.
# Can also be run by hand: bash pre-commit-gate.sh [PROJECT_DIR] </dev/null
# Git commit-msg hook mode: bash pre-commit-gate.sh --commit-msg MESSAGE_FILE
# Skip tests and lint (user decision only): SISKA_SKIP_GATE=1 git commit … (or --no-verify for the git hook).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Commit and PR text must describe the change, never the tool that wrote it (references/git.md).
ai_tools='claude|anthropic|openai|chatgpt|gpt-[0-9]|copilot|codex|gemini|cursor|devin|aider|windsurf'
ai_attribution() { # stdin: commit message or hook payload -> true if an AI attribution is present
  grep -Eiq -- "co-authored-by:.{0,80}($ai_tools)|(generated|created|written) (with|by) \\[?(claude|chatgpt|copilot|gemini|an? ai([^[:alnum:]]|$))"
}
attribution_block() {
  echo "Commit blocked by siska-lead-developer: remove the AI attribution (co-author trailer or 'Generated with …' line). Commit messages and PR text describe the technical change only." >&2
  exit 2
}

if [ "${1:-}" = --commit-msg ]; then
  [ -f "${2:-}" ] || { echo "usage: pre-commit-gate.sh --commit-msg MESSAGE_FILE" >&2; exit 2; }
  ai_attribution <"$2" && attribution_block
  exit 0
fi

input=""
[ -t 0 ] || input="$(cat)"
if [ -n "$input" ]; then
  # Hook mode: only act on git commits ("git -C dir commit", "git -c k=v commit" included) and PR texts.
  commit_re='git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+commit([^[:alnum:]-]|$)'
  if printf '%s' "$input" | grep -Eq "$commit_re|gh[[:space:]]+pr[[:space:]]+(create|edit)"; then
    printf '%s' "$input" | ai_attribution && attribution_block
  fi
  printf '%s' "$input" | grep -Eq "$commit_re" || exit 0
fi

# "cwd" from the hook payload; fall back to the argument or the current directory.
dir="$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
dir="${dir:-${1:-$PWD}}"

# Only guard git repositories.
git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
root="$(git -C "$dir" rev-parse --show-toplevel)"

# The secret scan cannot be turned off: a leaked key stays in the git history.
if ! report="$(bash "$SCRIPT_DIR/secret-scan.sh" "$root" 2>&1)"; then
  {
    echo "Commit blocked by siska-lead-developer: possible secret or sensitive file in the changes. Move the value to an environment variable or a secret manager, then commit again."
    printf '%s\n' "$report" | head -n 40
  } >&2
  exit 2
fi

# Explicit skip, visible in the command or the environment.
if [ "${SISKA_SKIP_GATE:-}" = 1 ] || printf '%s' "$input" | grep -Eq 'SISKA_SKIP_GATE=1[[:space:]]+git'; then
  echo "siska commit gate skipped (SISKA_SKIP_GATE=1): tests and lint were NOT run (secret scan passed)." >&2
  exit 0
fi

# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
if [ "$(sld_setting "$root" commit-gate)" = off ]; then
  echo "siska commit gate is OFF (settings): tests and lint were NOT run (secret scan passed). Turn it back on: settings gate on." >&2
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
