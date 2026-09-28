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
| `/siska-lead-developer:mcp <what to expose>` | Add / extend / audit an MCP server in the app |
| `/siska-lead-developer:check-code` | Pre-commit check: tests, linters, secrets, `.env`. Commit refused if anything fails (also enforced automatically on every `git commit`) |
| `/siska-lead-developer:check-code --front` | Same, front only (also `--back`, `--mobile`, combinable) |
| `/siska-lead-developer:document <feature>` | Feature documentation: functional, then technical (API calls…) · `--functional`, `--api`, `--code` |
| `/siska-lead-developer:tickets` | Open requests (T1, T2…) with status and priority · `--all` for every ticket |
| `/siska-lead-developer:tickets t2 done` | Change a ticket: `done`, `todo`, `progress`, `cancel`, `info`, `P1`–`P3`, or add instructions |
| `t3 <text>` (plain message) | Add instructions to ticket T3 |
| `/siska-lead-developer:help` | This list |
