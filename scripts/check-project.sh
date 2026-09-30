#!/usr/bin/env bash
# Pre-delivery project check.
#
# Usage: bash check-project.sh [PROJECT_DIR] [--run-tests] [--run-lint] [--scope front,back,mobile]
#
# Reports: detected stack, git state (branch, uncommitted changes), secrets,
# keys and tracked .env files (secret-scan.sh), debug leftovers in the current diff, and the test
# and lint commands found (or declared in .siska/checks, one per line).
# --run-tests / --run-lint run them; a failure is blocking. --scope limits them
# to front (web UI), back (PHP, Python, server-side Node) and/or mobile (Expo,
# React Native); in .siska/checks a line can be tagged "front: <command>".
# Read-only except for what the project's own commands do.
# Exit code: 0 ok (warnings allowed), 1 blocking problem found, 2 usage error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

ROOT_ARG="." RUN_TESTS=0 RUN_LINT=0 SCOPE="all" NEXT_IS_SCOPE=0
for arg in "$@"; do
  if [ $NEXT_IS_SCOPE -eq 1 ]; then SCOPE="$arg"; NEXT_IS_SCOPE=0; continue; fi
  case "$arg" in
    --scope) NEXT_IS_SCOPE=1 ;;
    --scope=*) SCOPE="${arg#--scope=}" ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --run-tests) RUN_TESTS=1 ;;
    --run-lint) RUN_LINT=1 ;;
    -*) sld_die "unknown option: $arg" ;;
    *) ROOT_ARG="$arg" ;;
  esac
done
[ $NEXT_IS_SCOPE -eq 0 ] || sld_die "--scope needs a value: front, back, mobile (comma-separated)"
for sc in ${SCOPE//,/ }; do
  case "$sc" in all|front|back|mobile) ;; *) sld_die "unknown scope: $sc (front, back, mobile)" ;; esac
done
ROOT="$(sld_project_root "$ROOT_ARG")"
BLOCKING=0

# Coloured status labels on a terminal only; agents and CI get the plain labels.
C_RED="" C_YEL="" C_GRN="" C_OFF=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then C_RED=$'\033[31m' C_YEL=$'\033[33m' C_GRN=$'\033[32m' C_OFF=$'\033[0m'; fi
block() { sld_info "${C_RED}BLOCK:${C_OFF} $*"; BLOCKING=1; }
warn() { sld_info "${C_YEL}WARN:${C_OFF}  $*"; }
ok() { sld_info "${C_GRN}OK:${C_OFF}    $*"; }

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

  # Secrets, keys, sensitive files and tracked .env (shared with the commit gate).
  if ! bash "$SCRIPT_DIR/secret-scan.sh" "$ROOT"; then BLOCKING=1; fi

  # Added lines of the whole working diff vs HEAD (staged + unstaged), plus untracked files.
  # Without any commit yet, compare with the empty tree so staged files are scanned too.
  base="HEAD"
  git -C "$ROOT" rev-parse --verify -q HEAD >/dev/null || base="$(git -C "$ROOT" hash-object -t tree /dev/null)"
  diff_added="$(git -C "$ROOT" diff "$base" --no-color -U0 2>/dev/null | grep -E '^\+[^+]' || true)"
  while IFS= read -r f; do
    # -I skips binary files.
    [ -f "$ROOT/$f" ] && diff_added+=$'\n'"$(grep -I '' "$ROOT/$f" 2>/dev/null | sed 's/^/+/')"
  done < <(git -C "$ROOT" ls-files --others --exclude-standard)

  debug_re='((^|[^[:alnum:]_>:$])(dd|dump)\(|var_dump\(|print_r\(|console\.log\(|(^|[^[:alnum:]_])debugger;|breakpoint\(\)|pdb\.set_trace\(\))'
  debug="$(printf '%s\n' "$diff_added" | grep -E -- "$debug_re" | cut -c1-120 || true)"
  if [ -n "$debug" ]; then warn "debug statement(s) in changes (remove unless intended):"; printf '%s\n' "$debug"; else ok "no debug statement in changes"; fi
else
  warn "not a git repository – diff review and secret scan skipped"
fi

sld_info ""
sld_info "## Tests and lint"
# Each entry: "kind|scope|dir|command" (kind: test, lint or check; scope: front, back, mobile or all).
CMDS=()
CUR_SCOPE=all
add_cmd() { CMDS+=("$1|$CUR_SCOPE|$2|$3"); sld_info "found: $1 ($CUR_SCOPE) [$2] $3"; }

# Scope of a Node project from its dependencies.
node_scope() {
  local p="$1/package.json" dep
  for dep in expo react-native; do sld_json_has_key "$p" "$dep" && { echo mobile; return; }; done
  for dep in next react vue nuxt vite svelte "@angular/core"; do sld_json_has_key "$p" "$dep" && { echo front; return; }; done
  echo back
}

in_scope() { # entry scope -> true if it must run for the requested --scope
  [ "$SCOPE" = all ] || [ "$1" = all ] || case ",$SCOPE," in *",$1,"*) true ;; *) false ;; esac
}

if [ -f "$ROOT/.siska/checks" ]; then
  # Project-declared checks replace detection: one shell command per line, run from the root.
  sld_info "using .siska/checks"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in
      front:*|back:*|mobile:*) CUR_SCOPE="${line%%:*}"; line="${line#*:}"; line="${line#"${line%%[![:space:]]*}"}" ;;
      *) CUR_SCOPE=all ;;
    esac
    add_cmd check . "$line"
  done <"$ROOT/.siska/checks"
else
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    d="$ROOT/$rel"
    if [ -f "$d/composer.json" ]; then
      CUR_SCOPE=back
      if sld_json_has_key "$d/composer.json" test; then add_cmd test "$rel" "composer test"
      elif [ -f "$d/artisan" ]; then add_cmd test "$rel" "php artisan test"
      elif [ -x "$d/vendor/bin/pest" ]; then add_cmd test "$rel" "vendor/bin/pest"
      elif [ -x "$d/vendor/bin/phpunit" ]; then add_cmd test "$rel" "vendor/bin/phpunit"
      fi
      if sld_json_has_key "$d/composer.json" lint; then add_cmd lint "$rel" "composer lint"
      elif [ -x "$d/vendor/bin/pint" ]; then add_cmd lint "$rel" "vendor/bin/pint --test"
      fi
      if [ -x "$d/vendor/bin/phpstan" ] && { [ -f "$d/phpstan.neon" ] || [ -f "$d/phpstan.neon.dist" ]; }; then
        add_cmd lint "$rel" "vendor/bin/phpstan analyse --no-progress"
      fi
    fi
    if [ -f "$d/package.json" ]; then
      CUR_SCOPE="$(node_scope "$d")"
      pm="$(sld_node_pm "$d")"; pm="${pm%% *}"
      if sld_json_has_key "$d/package.json" test && ! grep -q 'no test specified' "$d/package.json"; then
        add_cmd test "$rel" "$pm test"
      fi
      for script in lint typecheck type-check; do
        sld_json_has_key "$d/package.json" "$script" && add_cmd lint "$rel" "$pm run $script"
      done
    fi
    CUR_SCOPE=back
    if [ -f "$d/pytest.ini" ] || [ -f "$d/conftest.py" ] || grep -q '\[tool.pytest' "$d/pyproject.toml" 2>/dev/null || sld_py_has_dep "$d" pytest; then
      add_cmd test "$rel" "pytest"
    fi
    if sld_has_cmd ruff && { [ -f "$d/ruff.toml" ] || [ -f "$d/.ruff.toml" ] || grep -q '\[tool.ruff' "$d/pyproject.toml" 2>/dev/null; }; then
      add_cmd lint "$rel" "ruff check ."
    fi
  done <<<"$(sld_project_dirs "$ROOT")"
fi

if [ ${#CMDS[@]} -eq 0 ]; then
  warn "no test or lint command detected – declare them in .siska/checks, or verify manually and report it"
elif [ $RUN_TESTS -eq 0 ] && [ $RUN_LINT -eq 0 ]; then
  sld_info "(run with --run-tests and/or --run-lint to execute them)"
else
  RAN=0
  for entry in "${CMDS[@]}"; do
    kind="${entry%%|*}" rest="${entry#*|}"
    scope="${rest%%|*}" rest="${rest#*|}"
    rel="${rest%%|*}" cmd="${rest#*|}"
    in_scope "$scope" || continue
    case "$kind" in
      test) [ $RUN_TESTS -eq 1 ] || continue ;;
      lint) [ $RUN_LINT -eq 1 ] || continue ;;
    esac
    sld_info "RUN [$rel] $cmd"
    RAN=$((RAN + 1))
    # Commands come from detection above or from the project's own .siska/checks.
    if (cd "$ROOT/$rel" && bash -c "$cmd"); then ok "[$rel] $cmd"; else block "[$rel] $cmd failed"; fi
  done
  [ $RAN -gt 0 ] || warn "no test or lint command for scope '$SCOPE' – that part is NOT verified"
fi

sld_info ""
if [ $BLOCKING -eq 1 ]; then sld_info "RESULT: blocking problem(s) – not ready to deliver"; exit 1; fi
sld_info "RESULT: no blocking problem detected (read WARN lines; this does not replace the diff review)"
