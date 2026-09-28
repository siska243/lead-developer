#!/usr/bin/env bash
# Pre-delivery project check.
#
# Usage: bash check-project.sh [PROJECT_DIR] [--run-tests]
#
# Reports: detected stack, git state (branch, uncommitted changes), tracked
# .env files, secrets and debug leftovers in the current diff, and the test
# commands found. With --run-tests, runs those test commands.
# Read-only except for what the project's own test commands do.
# Exit code: 0 ok (warnings allowed), 1 blocking problem found, 2 usage error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

ROOT_ARG="." RUN_TESTS=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --run-tests) RUN_TESTS=1 ;;
    -*) sld_die "unknown option: $arg" ;;
    *) ROOT_ARG="$arg" ;;
  esac
done
ROOT="$(sld_project_root "$ROOT_ARG")"
BLOCKING=0

block() { sld_info "BLOCK: $*"; BLOCKING=1; }
warn() { sld_info "WARN:  $*"; }
ok() { sld_info "OK:    $*"; }

sld_info "## Stack"
bash "$SCRIPT_DIR/detect-stack.sh" "$ROOT"

sld_info ""
sld_info "## Git"
if sld_has_cmd git && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch="$(sld_git_branch "$ROOT")"
  case "$branch" in
    main|master|develop|production|prod) warn "on '$branch' – work should happen on a ticket branch (see references/git.md)" ;;
    *) ok "branch '$branch'" ;;
  esac
  git -C "$ROOT" status --short

  tracked_env="$(git -C "$ROOT" ls-files | grep -E '(^|/)\.env(\.[^/]*)?$' | grep -Ev '\.(example|sample|dist|template)$' || true)"
  if [ -n "$tracked_env" ]; then block "environment file(s) tracked by git: $(echo "$tracked_env" | tr '\n' ' ')"; else ok "no .env file tracked"; fi

  # Added lines of the whole working diff vs HEAD (staged + unstaged), plus untracked files.
  # Without any commit yet, compare with the empty tree so staged files are scanned too.
  base="HEAD"
  git -C "$ROOT" rev-parse --verify -q HEAD >/dev/null || base="$(git -C "$ROOT" hash-object -t tree /dev/null)"
  diff_added="$(git -C "$ROOT" diff "$base" --no-color -U0 2>/dev/null | grep -E '^\+[^+]' || true)"
  while IFS= read -r f; do
    # -I skips binary files.
    [ -f "$ROOT/$f" ] && diff_added+=$'\n'"$(grep -I '' "$ROOT/$f" 2>/dev/null | sed 's/^/+/')"
  done < <(git -C "$ROOT" ls-files --others --exclude-standard)

  secret_re='(-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36,}|xox[baprs]-[A-Za-z0-9-]{10,}|sk_live_[0-9A-Za-z]{16,}|(password|passwd|secret|api_key|apikey|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'[:space:]]{8,}["'"'"'])'
  secrets="$(printf '%s\n' "$diff_added" | grep -Ei -- "$secret_re" | cut -c1-120 || true)"
  if [ -n "$secrets" ]; then block "possible secret(s) in changes:"; printf '%s\n' "$secrets"; else ok "no secret pattern in changes"; fi

  debug_re='((^|[^[:alnum:]_>:$])(dd|dump)\(|var_dump\(|print_r\(|console\.log\(|(^|[^[:alnum:]_])debugger;|breakpoint\(\)|pdb\.set_trace\(\))'
  debug="$(printf '%s\n' "$diff_added" | grep -E -- "$debug_re" | cut -c1-120 || true)"
  if [ -n "$debug" ]; then warn "debug statement(s) in changes (remove unless intended):"; printf '%s\n' "$debug"; else ok "no debug statement in changes"; fi
else
  warn "not a git repository – diff review and secret scan skipped"
fi

sld_info ""
sld_info "## Tests"
TEST_CMDS=()
add_test() { TEST_CMDS+=("$1|$2"); sld_info "found: [$1] $2"; }

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  d="$ROOT/$rel"
  if [ -f "$d/composer.json" ]; then
    if grep -Eq '"test"[[:space:]]*:' "$d/composer.json"; then add_test "$rel" "composer test"
    elif [ -f "$d/artisan" ]; then add_test "$rel" "php artisan test"
    elif [ -x "$d/vendor/bin/pest" ]; then add_test "$rel" "vendor/bin/pest"
    elif [ -x "$d/vendor/bin/phpunit" ]; then add_test "$rel" "vendor/bin/phpunit"
    fi
  fi
  if [ -f "$d/package.json" ] && grep -Eq '"test"[[:space:]]*:' "$d/package.json" \
     && ! grep -q 'no test specified' "$d/package.json"; then
    pm="$(sld_node_pm "$d")"; pm="${pm%% *}"
    add_test "$rel" "$pm test"
  fi
  if [ -f "$d/pytest.ini" ] || [ -f "$d/conftest.py" ] || grep -q '\[tool.pytest' "$d/pyproject.toml" 2>/dev/null || sld_py_has_dep "$d" pytest; then
    add_test "$rel" "pytest"
  fi
done <<<"$(sld_project_dirs "$ROOT")"

if [ ${#TEST_CMDS[@]} -eq 0 ]; then
  warn "no test command detected – verify manually and report it"
elif [ $RUN_TESTS -eq 1 ]; then
  for entry in "${TEST_CMDS[@]}"; do
    rel="${entry%%|*}" cmd="${entry#*|}"
    sld_info "RUN [$rel] $cmd"
    # Word splitting of $cmd is intended: commands come from the fixed list above.
    # shellcheck disable=SC2086
    if (cd "$ROOT/$rel" && $cmd); then ok "[$rel] $cmd"; else block "[$rel] $cmd failed"; fi
  done
else
  sld_info "(run with --run-tests to execute them)"
fi

sld_info ""
if [ $BLOCKING -eq 1 ]; then sld_info "RESULT: blocking problem(s) – not ready to deliver"; exit 1; fi
sld_info "RESULT: no blocking problem detected (read WARN lines; this does not replace the diff review)"
