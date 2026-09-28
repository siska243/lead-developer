#!/usr/bin/env bash
# Turn siska-lead-developer automations on or off.
#
# Usage: bash settings.sh [PROJECT_DIR] [--global] [gate|ledger on|off]
#   no key: show the current state
#   gate:   commit gate (tests, lint, secrets before every commit)
#   ledger: request ledger hooks (reminder on each message, update required)
# Stored in PROJECT/.siska/settings, or ~/.siska/settings with --global
# (the project value wins). Only change it when the user asks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

ROOT_ARG="." GLOBAL=0 ARGS=()
for arg in "$@"; do
  case "$arg" in
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --global) GLOBAL=1 ;;
    gate|ledger|on|off) ARGS+=("$arg") ;;
    -*) sld_die "unknown option: $arg" ;;
    *) ROOT_ARG="$arg" ;;
  esac
done
ROOT="$(git -C "$ROOT_ARG" rev-parse --show-toplevel 2>/dev/null || sld_project_root "$ROOT_ARG")"

key_name() { case "$1" in gate) echo commit-gate ;; ledger) echo ledger ;; esac; }

if [ ${#ARGS[@]} -eq 2 ]; then
  key="$(key_name "${ARGS[0]}")"; value="${ARGS[1]}"
  case "$key:$value" in ?*:on|?*:off) ;; *) sld_die "usage: settings.sh [--global] gate|ledger on|off" ;; esac
  if [ $GLOBAL -eq 1 ]; then FILE="${SLD_HOME:-$HOME}/.siska/settings"; else FILE="$ROOT/.siska/settings"; fi
  mkdir -p "$(dirname "$FILE")"
  { grep -v "^${key}[[:space:]]*=" "$FILE" 2>/dev/null || true; echo "$key=$value"; } >"$FILE.tmp" && mv "$FILE.tmp" "$FILE"
  sld_info "$key=$value ($FILE)"
elif [ ${#ARGS[@]} -ne 0 ]; then
  sld_die "usage: settings.sh [--global] gate|ledger on|off"
fi
sld_info "commit gate: $(sld_setting "$ROOT" commit-gate)"
sld_info "ledger:      $(sld_setting "$ROOT" ledger)"
