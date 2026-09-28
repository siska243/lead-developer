---
name: tickets
description: Show or update the request ledger (T1, T2…) - statuses todo, in progress, done, needs info, cancelled.
argument-hint: "[--all | t<n> <status|P1-P3|instructions>]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

Use the ledger defined in `${CLAUDE_SKILL_DIR}/../../references/requests.md` (file `.siska/requests.md` at the project root).

- No arguments: show the summary table of tickets that are not ✅ done or ❌ cancelled.
- `--all`: show every ticket.
- `t<n> done|todo|progress|cancel|info`: set that ticket's status. `done` only with a verified result: otherwise say what is missing.
- `t<n> P1|P2|P3`: set its priority.
- `t<n> <text>`: add the text to its instructions (reopens it if it was done).

Update the file, then show the summary table. No other output.
