#!/usr/bin/env bash
# Request ledger enforcement for agents with prompt/stop hooks (Claude Code plugin).
#
# Usage (hook JSON on stdin): bash ledger-hook.sh prompt | stop
#   prompt: remind the agent to record the message and list the open tickets
#           of .siska/requests.md (stdout becomes context for the agent).
#   stop:   block the end of the response (exit 2) while the ledger was not
#           updated since the user's message. At most 2 blocks per message.
# Only active inside git repositories. SLD_STATE_DIR overrides the state dir.
set -uo pipefail

MODE="${1:-}"
input=""
[ -t 0 ] || input="$(cat)"
field() { printf '%s' "$input" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1; }

dir="$(field cwd)"; dir="${dir:-$PWD}"
root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0
LEDGER="$root/.siska/requests.md"
session="$(field session_id | tr -cd '[:alnum:]_-')"
STATE="${SLD_STATE_DIR:-${TMPDIR:-/tmp}}/siska-ledger-${session:-default}"

case "$MODE" in
  prompt)
    echo 0 >"$STATE"   # marks the time of the user's message; 0 blocks so far
    echo "siska-lead-developer ledger: record this user message in $LEDGER (references/requests.md): new ticket T<next>, or update the ticket it refers to (t<n>, duplicate, answer to a question). End the response with the ticket table."
    echo "Ledger format, one section per ticket (keep exactly):"
    echo "## T<n> · <short title>"
    echo "- Status: <⬜ todo | 🔄 in progress | ✅ done | ❓ needs info | ❌ cancelled> · Priority: <P1|P2|P3> · Created: <date> · Updated: <date>"
    echo "- Instructions: dated lines, in the user's words"
    echo "- Result: what was done and how it was verified"
    echo "- Question: open question, or –"
    if [ -f "$LEDGER" ]; then
      open="$(awk '/^## T[0-9]+/{t=$0} /^- Status:/{ s=$0; sub(/^- Status: /,"",s); sub(/ ·.*/,"",s); if (t != "" && s !~ /(✅|❌)/) print t " — " s; t="" }' "$LEDGER")"
      if [ -n "$open" ]; then echo "Open tickets:"; printf '%s\n' "$open" | sed 's/^## /- /'; else echo "Open tickets: none."; fi
    else
      echo "No ledger yet: create it with this request as T1."
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
