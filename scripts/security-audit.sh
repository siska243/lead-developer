#!/usr/bin/env bash
# Audit project dependencies for known vulnerabilities (read-only).
#
# Usage: bash security-audit.sh [PROJECT_DIR] [--outdated]
#
# Detects every (sub)project, then runs the audit tool of the package manager
# actually used (composer, npm, pnpm, yarn, bun, pip-audit). Never installs,
# updates or modifies anything. Missing tools are reported as SKIP.
# Exit code: 0 no finding, 1 at least one audit reported issues, 2 usage error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

ROOT_ARG="." OUTDATED=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --outdated) OUTDATED=1 ;;
    -*) sld_die "unknown option: $arg" ;;
    *) ROOT_ARG="$arg" ;;
  esac
done
ROOT="$(sld_project_root "$ROOT_ARG")"

FAILED=0 RAN=0

# run LABEL DIR TOOL CMD... : run an audit command in DIR, record the result.
run() {
  local label="$1" dir="$2" tool="$3"; shift 3
  if ! sld_has_cmd "$tool"; then
    sld_info "SKIP [$label] $tool not installed"
    return
  fi
  sld_info "RUN  [$label] $*"
  RAN=$((RAN + 1))
  if (cd "$dir" && "$@"); then
    sld_info "OK   [$label]"
  else
    sld_info "FAIL [$label] issues reported (or tool error) – read the output above"
    FAILED=1
  fi
}

# Outdated reports are informational: they never fail the audit.
info() {
  local label="$1" dir="$2" tool="$3"; shift 3
  sld_has_cmd "$tool" || return 0
  sld_info "INFO [$label] $*"
  (cd "$dir" && "$@") || true
}

audit_dir() {
  local rel="$1" d="$ROOT/$1"

  if [ -f "$d/composer.json" ]; then
    if [ -f "$d/composer.lock" ]; then
      run "$rel composer" "$d" composer composer audit --locked --no-interaction
    else
      sld_warn "[$rel] composer.json without composer.lock – cannot audit resolved versions"
    fi
    [ $OUTDATED -eq 1 ] && info "$rel composer" "$d" composer composer outdated --direct --no-interaction
  fi

  if [ -f "$d/package.json" ]; then
    case "$(sld_node_pm "$d")" in
      pnpm) run "$rel pnpm" "$d" pnpm pnpm audit
            [ $OUTDATED -eq 1 ] && info "$rel pnpm" "$d" pnpm pnpm outdated ;;
      yarn) if [ -f "$d/.yarnrc.yml" ]; then
              run "$rel yarn" "$d" yarn yarn npm audit --recursive
            else
              run "$rel yarn" "$d" yarn yarn audit
            fi
            [ $OUTDATED -eq 1 ] && info "$rel yarn" "$d" yarn yarn outdated ;;
      bun)  run "$rel bun" "$d" bun bun audit
            [ $OUTDATED -eq 1 ] && info "$rel bun" "$d" bun bun outdated ;;
      npm)  run "$rel npm" "$d" npm npm audit
            [ $OUTDATED -eq 1 ] && info "$rel npm" "$d" npm npm outdated ;;
      *)    sld_warn "[$rel] package.json without lockfile – cannot audit resolved versions" ;;
    esac
  fi

  local req found_req=0
  for req in "$d"/requirements*.txt; do
    [ -f "$req" ] || continue
    found_req=1
    run "$rel pip-audit $(basename "$req")" "$d" pip-audit pip-audit -r "$req"
  done
  if [ $found_req -eq 0 ] && { [ -f "$d/pyproject.toml" ] || [ -f "$d/Pipfile" ]; }; then
    # Without a requirements file, pip-audit can only audit an installed environment.
    sld_warn "[$rel] Python project without requirements*.txt – run 'pip-audit' inside its activated virtualenv (or export requirements first)"
  fi
}

sld_info "project: $ROOT"
dirs="$(sld_project_dirs "$ROOT")"
[ -n "$dirs" ] || { sld_info "no dependency manifest found – nothing to audit"; exit 0; }
while IFS= read -r rel; do audit_dir "$rel"; done <<<"$dirs"

sld_info "---"
if [ $RAN -eq 0 ]; then
  sld_info "RESULT: no audit could run (tools missing or no lockfile) – dependencies NOT verified"
  exit 1
fi
if [ $FAILED -eq 1 ]; then sld_info "RESULT: issues found – see FAIL lines"; exit 1; fi
sld_info "RESULT: no known vulnerability reported by $RAN audit(s)"
