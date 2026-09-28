# Request ledger

Goal: no request is skipped, forgotten, overwritten by the latest one, or done twice.
Every request of the user gets an ID, a priority and a status, kept in a ledger.

## Ledger file
`.siska/requests.md` at the project root (create it on the first request; tell the user once, they decide whether to commit or git-ignore it).
No project directory → keep the ledger in the conversation with the same format.
At session start, if the file exists: read it first and show the open tickets.

```markdown
# Requests

## T1 · Add status filter to GET /orders
- Status: ✅ done · Priority: P2 · Created: 2026-09-28 · Updated: 2026-09-28
- Instructions:
  - 2026-09-28: filter by `status` query parameter
  - 2026-09-28 (added): also apply it to the CSV export
- Result: `OrderService::listFor` + controller validation; `OrderApiTest` passes; commit `abc123`
- Question: –
```
Write the request and instructions in the user's words and language. Keep the emoji of each status.

## Statuses
| Status | When |
|--------|------|
| ⬜ todo | Recorded, not started |
| 🔄 in progress | Being worked on now |
| ✅ done | Delivered **and verified** (tests/commands run, result written in `Result`) |
| ❓ needs info | Blocked on the user: the exact question is in `Question` |
| ❌ cancelled | The user cancelled it, or it was replaced by another ticket (write which) |

## Priorities
`P1` urgent or blocking (production down, security, "urgent") · `P2` normal (default) · `P3` nice to have.
Infer it, show it, the user corrects it (`t2 P1`).

## On every user message
1. **Split** the message into distinct requests (one message can hold several).
2. **Reference**: a message starting with `T<n>` / `t<n>` targets that ticket. Append its text to that ticket's instructions, dated. If the ticket was ✅ done, it reopens it (status back to ⬜ todo, note "reopened").
3. **Duplicate check** before creating a ticket: search the ledger for the same or a similar request.
   - Similar ticket still open → add the text as instructions to it, no new ticket.
   - Similar ticket ✅ done → do not redo it. Tell the user: "Already done in T3 (date, result). Redo it, or what should be improved?" Record a new ticket as ❓ needs info until they answer.
4. **Create** each new request as `T<next number>` with ⬜ todo and its priority.
5. **Order of work**: P1 first, then oldest first. A new request never silently replaces the current one: record it, say where it sits in the queue, and keep going. Switch only if it is P1 or the user says so.
6. **Update** the ledger file whenever a status changes.

## End of every response
Show the ledger summary: every ticket that is not closed, plus every ticket changed in this response.

```markdown
| ID | Request | P | Status | Next |
|----|---------|---|--------|------|
| T1 | Status filter on GET /orders | P2 | ✅ done | – |
| T2 | Pagination on GET /orders | P2 | 🔄 in progress | tests |
| T3 | Dark mode on invoices page | P3 | ⬜ todo | after T2 |
| T4 | Export to Excel | P2 | ❓ needs info | CSV or XLSX? |
```
If any ⬜ or 🔄 ticket remains, say so in one line. Never end with "all done" while one is open.
