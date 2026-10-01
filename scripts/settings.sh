#!/usr/bin/env bash
# Turn siska-lead-developer automations on or off.
#
# Usage: bash settings.sh [PROJECT_DIR] [--global] [gate|ledger|micro on|off] [language <code>|auto]
#   no key: show the current state
#   gate:   commit gate (tests, lint, secrets before every commit) – on by default
#   ledger: request ledger hooks (reminder on each message, update required) – on by default
#   micro:  micro-task mode (tasks split into 2–4 verified micro-tasks, references/microtasks.md) – off by default
#   language: language the agent answers the developer in and writes visual reports in (fr, en, es,
#             pt-BR…); auto (default) = the language of the developer's messages. Project files
#             (code, database, docs, commits) are always English.
# Stored in PROJECT/.siska/settings, or ~/.siska/settings with --global
# (the project value wins). Only change it when the user asks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

ROOT_ARG="." GLOBAL=0 ARGS=() NEXT_IS_LANG=0
for arg in "$@"; do
  if [ $NEXT_IS_LANG -eq 1 ]; then
    [[ "$arg" =~ ^(auto|[a-z]{2,3}(-[A-Z]{2})?)$ ]] || sld_die "language must be auto or a language code (fr, en, es, pt-BR…): $arg"
    ARGS+=("$arg"); NEXT_IS_LANG=0; continue
  fi
  case "$arg" in
    language) ARGS+=("$arg"); NEXT_IS_LANG=1 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --global) GLOBAL=1 ;;
    gate|ledger|micro|on|off) ARGS+=("$arg") ;;
    -*) sld_die "unknown option: $arg" ;;
    *) ROOT_ARG="$arg" ;;
  esac
done
ROOT="$(git -C "$ROOT_ARG" rev-parse --show-toplevel 2>/dev/null || sld_project_root "$ROOT_ARG")"

key_name() { case "$1" in gate) echo commit-gate ;; ledger) echo ledger ;; micro) echo micro-tasks ;; language) echo language ;; esac; }

if [ ${#ARGS[@]} -eq 2 ]; then
  key="$(key_name "${ARGS[0]}")"; value="${ARGS[1]}"
  case "$key:$value" in language:*|?*:on|?*:off) ;; *) sld_die "usage: settings.sh [--global] gate|ledger|micro on|off | language <code>|auto" ;; esac
  if [ $GLOBAL -eq 1 ]; then FILE="${SLD_HOME:-$HOME}/.siska/settings"; else FILE="$ROOT/.siska/settings"; fi
  mkdir -p "$(dirname "$FILE")"
  { grep -v "^${key}[[:space:]]*=" "$FILE" 2>/dev/null || true; echo "$key=$value"; } >"$FILE.tmp" && mv "$FILE.tmp" "$FILE"
  sld_info "$key=$value ($FILE)"
elif [ ${#ARGS[@]} -ne 0 ]; then
  sld_die "usage: settings.sh [--global] gate|ledger|micro on|off"
fi
sld_info "commit gate: $(sld_setting "$ROOT" commit-gate)"
sld_info "ledger:      $(sld_setting "$ROOT" ledger)"
sld_info "micro-tasks: $(sld_setting "$ROOT" micro-tasks off)"
sld_info "language:    $(sld_setting "$ROOT" language auto)"
