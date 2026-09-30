---
name: help
description: List every siska-lead-developer command and what it does.
disable-model-invocation: true
---

Reply with exactly this table, nothing else:

| Command | Does |
|---------|------|
| `/siska-lead-developer:siska-lead-developer <task>` | Any dev task as Lead Developer (feature, bug, TMA, review, new project, UI). Also triggers automatically. |
| `/siska-lead-developer:audit-route` | Security audit of all API routes (auth, permissions, validation, rate limiting…) |
| `/siska-lead-developer:audit-route --orders` | Same, only routes matching `orders` (also: `POST /orders`, `--api/v1/users`) |
| `/siska-lead-developer:audit-package` | Dependencies: vulnerabilities, abandoned/unmaintained, unused (then removal on approval) |
| `/siska-lead-developer:audit-package --outdated` | Same + outdated packages |
| `/siska-lead-developer:optimize` | Code optimization: API fields the front never uses, useless front requests, heavy pages, slow backend code, dead and duplicated code; fixes after your yes |
| `/siska-lead-developer:optimize https://app.local/orders` | Give a page link: it scans the page, gives a summary and a plan, applies it on a `perf/` branch (risky items wait for your yes), then shows before → after |
| `/siska-lead-developer:optimize com.company.app --flow .maestro/orders.yaml` | Mobile: measures the app on a device or emulator (cold start, janky frames, memory), summary, plan, applied, before → after |
| `/siska-lead-developer:optimize front --orders` | Only some parts (`api`, `front`, `back`, `dead`, combinable), only what matches `orders` |
| `/siska-lead-developer:mcp <what to expose>` | Add / extend / audit an MCP server in the app |
| `/siska-lead-developer:check-code` | Pre-commit check: tests, linters, secrets, keys, `.env`. Commit refused if anything fails (also enforced automatically on every `git commit`; secrets and AI co-author trailers are always checked) |
| `/siska-lead-developer:check-code --history` | Secret scan of the whole git history (every commit, values masked): what must be rotated |
| `/siska-lead-developer:check-code --perf` | Performance budgets: each page and app of `.siska/perf-budget.json` measured, blocked if heavier or slower than allowed or than its baseline |
| `/siska-lead-developer:check-code --front` | Same, front only (also `--back`, `--mobile`, combinable) |
| `/siska-lead-developer:document <feature>` | Feature documentation: functional, then technical (API calls…) · `--functional`, `--api`, `--code` |
| `/siska-lead-developer:skills` | Installed skills and MCP · `find <need>` · `vet <source>` · `install <source>` (only after your yes) |
| `/siska-lead-developer:tickets` | Open requests (T1, T2…) with status and priority · `--all` for every ticket |
| `/siska-lead-developer:tickets t2 done` | Change a ticket: `done`, `todo`, `progress`, `cancel`, `info`, `P1`–`P3`, or add instructions |
| `t3 <text>` (plain message) | Add instructions to ticket T3 |
| `/siska-lead-developer:settings gate off` | Turn the commit gate off/on (`gate on`), or the ledger (`ledger off`); `--global` for all projects; no argument = status |
| `/siska-lead-developer:help` | This list |
