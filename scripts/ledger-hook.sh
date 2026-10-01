#!/usr/bin/env bash
# Request ledger enforcement for agents with prompt/stop hooks (Claude Code plugin).
#
# Usage (hook JSON on stdin): bash ledger-hook.sh prompt | stop
#   prompt: remind the agent to record the message and list the open tickets
#           of .siska/requests.md (stdout becomes context for the agent).
#   stop:   block the end of the response (exit 2) while the ledger was not
#           updated since the user's message. At most 2 blocks per message.
# Micro-task mode (settings micro on): the prompt hook also reminds the micro-task rules,
# even when the ledger is off.
# Only active inside git repositories. SLD_STATE_DIR overrides the state dir.
set -uo pipefail

MODE="${1:-}"
input=""
[ -t 0 ] || input="$(cat)"
field() { printf '%s' "$input" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1; }

dir="$(field cwd)"; dir="${dir:-$PWD}"
root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
micro_reminder() {
  [ "$(sld_setting "$root" micro-tasks off)" = on ] || return 0
  echo "siska micro-tasks ON (references/microtasks.md): split any non-trivial task into 2–4 micro-tasks, each with one verifiable result. Before each: say in 2–3 lines what, why, how it will be checked. After each: verify (tests, lint, diff), report briefly, then the next. Sub-agents: one micro-task each with files and acceptance criteria; read their diff and re-run the checks before integrating. Track them as T<n>.1, T<n>.2 in the ticket."
}
if [ "$(sld_setting "$root" ledger)" = off ]; then
  [ "$MODE" = prompt ] && micro_reminder
  exit 0
fi
LEDGER="$root/.siska/requests.md"
session="$(field session_id | tr -cd '[:alnum:]_-')"
STATE="${SLD_STATE_DIR:-${TMPDIR:-/tmp}}/siska-ledger-${session:-default}"

case "$MODE" in
  prompt)
    if [ -f "$LEDGER" ]; then
      # Move closed tickets (✅/❌) to the archive so the active file stays small.
      ARCHIVE="$root/.siska/requests-archive.md"
      awk -v arch="$ARCHIVE" '
        /^## T[0-9]+/ { flush(); buf=$0 "\n"; closed=0; next }
        buf != ""     { buf=buf $0 "\n"; if ($0 ~ /^- Status:/ && $0 ~ /(✅|❌)/) closed=1; next }
                      { print }
        function flush() { if (buf == "") return; if (closed) printf "%s", buf >> arch; else printf "%s", buf; buf="" }
        END { flush() }' "$LEDGER" >"$LEDGER.tmp" && mv "$LEDGER.tmp" "$LEDGER"
    fi
    echo 0 >"$STATE"   # marks the time of the user's message; 0 blocks so far
    micro_reminder
    echo "siska ledger: record this message in .siska/requests.md (new T<n>, or update the ticket it refers to). Append new tickets without reading the file; to change one, read only its lines. Duplicates: grep .siska/requests-archive.md. End with a compact table of open or changed tickets."
    echo "Format: '## T<n> · <title>' / '- Status: <⬜ todo|🔄 in progress|✅ done|❓ needs info|❌ cancelled> · Priority: <P1-P3> · Created: <date> · Updated: <date>' / '- Instructions:' dated lines / '- Result:' / '- Question:'"
    if [ -f "$LEDGER" ]; then
      open="$(awk '/^## T[0-9]+/{t=$0} /^- Status:/{ s=$0; sub(/^- Status: /,"",s); sub(/ ·.*/,"",s); if (t != "") print t " — " s; t="" }' "$LEDGER")"
      last="$(cat "$LEDGER" "$root/.siska/requests-archive.md" 2>/dev/null | sed -n 's/^## T\([0-9]*\).*/\1/p' | sort -n | tail -n 1)"
      echo "Open: ${open:+$'\n'}${open:-none}" | sed 's/^## /- /'
      echo "Last ID: T${last:-0}"
    else
      echo "No ledger yet: create it, this request is T1."
    fi
    ;;
  stop)
    [ -f "$STATE" ] || exit 0
    [ -f "$LEDGER" ] && [ "$LEDGER" -nt "$STATE" ] && exit 0
    blocks="$(cat "$STATE" 2>/dev/null || echo 0)"
    if [ "${blocks:-0}" -ge 2 ]; then
      echo "siska ledger: still not updated after 2 reminders – stopping anyway." >&2
      exit 0
    fi
    # Keep the message time (mtime) while counting blocks.
    printf '%s\n' "$((blocks + 1))" >"$STATE.tmp" && touch -r "$STATE" "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    echo "Before finishing: update $LEDGER for the user's last message (references/requests.md) – record or update the ticket(s), set their status – then show the ticket table." >&2
    exit 2
    ;;
  *) echo "usage: ledger-hook.sh prompt|stop" >&2; exit 2 ;;
esac
