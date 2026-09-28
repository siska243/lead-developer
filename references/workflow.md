# Workflow

Load for any non-trivial task.

## 1. Understand
- Restate the need in one sentence. If two readings are possible, ask.
- Identify: existing app or new project? In production? Who uses the impacted feature?

## 2. Explore (never blind)
Run `bash scripts/detect-stack.sh <project>`, then read what the task touches:
architecture, routes, controllers, services, repositories, models/entities, components,
hooks, stores, middlewares, policies, requests/validators, migrations, tests, config,
dependencies, CI/CD, docs, design system. Follow the real call chain end to end.

## 3. Impact analysis
| Level | Look for |
|-------|----------|
| Direct | file, class, function, component, endpoint, table, screen |
| Indirect | callers, parent/child components, API clients (web, mobile, third parties), jobs, queues, events, listeners, notifications, cache keys, permissions, workflows, tests |
| Risks | functional, UX, UI, performance, security, API contract, mobile, production data |

Search every usage (`grep -rn`, IDE references, code-graph tools if available) before changing a shared symbol.

## 4. Plan
Required fields: goal · scope (in / out) · files · dependencies · risks · strategy · tests · anti-regression checks · expected result.
Trivial change → 3 lines. Complex change → detailed, validated with the user when it changes behavior, data or contracts.
Before acting, explain simply what you will do and why: 2–5 plain sentences a non-developer can follow, no unexplained jargon.

## 5. Anti-regression matrix
Write "what could break?" then verify each item.

| Ticket type | Check chain |
|-------------|-------------|
| API | endpoint → service → database → every client |
| Mobile | navigation → state → API → UI → performance |
| Frontend | component → parent → state → API → responsive |
| Database | migration → existing data → indexes/constraints → queries → rollback |
| Auth / permissions | every role × every impacted action |

## 6. Implement
Minimum complete change. Project conventions first. See `clean-code.md`.

## 7. Verify
- Existing test suite (see `testing.md`) + new tests for new behavior and edge cases.
- Project linters, formatters and static analysis on changed files (see `clean-code.md` → Uniformity).
- UI: no new hardcoded color/spacing/font, no duplicate component (see `design-system.md` → Strict rules).
- Each anti-regression item checked, with evidence.
- Security (`security.md`) and dependency audit when relevant.
- UI states (`ux.md`) when UI changed. Performance (`performance.md`) when queries, rendering or payloads changed.

## 8. Review the diff
`git status && git diff` (plus `git diff --staged`). Check: modified / new / deleted files, dependencies, config, migrations, tests, docs, secrets.
For every hunk: **is it necessary for this ticket?** If not, revert it.

## 9. Deliver
Report: what changed, how it was verified (commands + results), limitations, out-of-scope findings proposed as separate tickets.

## Delivery checklist
**Analysis** – need understood · project analyzed · existing code searched · constraints and risks identified
**Plan** – plan when needed · scope defined · anti-regression strategy defined
**Implementation** – minimal code · clean code · uniform with the codebase (one way to do one thing) · linters pass · nothing invented · no workaround · no voluntary tech debt
**Security** – inputs validated · permissions checked · secrets protected · dependencies audited
**UI/UX** – design system and brand respected to the letter (tokens only, one component per purpose) · coherent UX · loading/error/empty/disabled states · responsive · accessible · motion coherent if used
**Performance** – queries · API calls · rendering · bundle when relevant · animations when relevant
**Tests** – existing tests run · new tests where needed · regression verified · edge cases verified
**Review** – diff checked · no useless change or file · no secret · no unjustified out-of-scope change
**Delivery** – really finished · docs updated · limitations reported · result verified

## Quality gate
Answer yes to all before delivering: exact need met? existing preserved? regressions checked? maintainable? secure? performant? UX coherent? design system respected? scope respected? tests sufficient?
