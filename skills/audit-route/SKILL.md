---
name: audit-route
description: Security audit of the project's API routes, optionally filtered (e.g. --orders).
argument-hint: "[--<route-filter>]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

Read-only security audit of routes. Apply the rules of `${CLAUDE_SKILL_DIR}/../../SKILL.md` and the checklist of `${CLAUDE_SKILL_DIR}/../../references/security.md`. Change no code unless the user asks after the report.

1. **Filter**: strip leading `--` from the arguments. Empty = every route. Otherwise keep routes whose path, name or controller contains the filter (`orders`, `POST /orders`, `api/v1/users`).
2. **List the real routes** with the framework, not by guessing:
   - Laravel: `php artisan route:list -v --path=<filter>` (or `--json`)
   - Symfony: `php bin/console debug:router`
   - Express / Nest / Next.js / FastAPI / others: read the route definitions in code (FastAPI: also `/openapi.json` if running)
   - Stack unknown: `bash ${CLAUDE_SKILL_DIR}/../../scripts/detect-stack.sh .`
3. **For each route, read the full chain** (middleware → controller → request/validator → service → policy → model) and check: authentication, authorization (role + resource ownership/tenant), input validation and mass assignment, SQL injection, XSS, CSRF, SSRF, uploads, rate limiting, CORS, error/data exposure, secrets.
4. **Report, short**:
   - one table: `Method | Route | Auth | Authz | Validation | Rate limit | Risk (OK/Low/Medium/High/Critical)`
   - then only the findings: `file:line` · problem · concrete exploit scenario · minimal fix
   - state what could not be verified (e.g. runtime config, reverse proxy)
   Deliver it as a visual report with the link, following `${CLAUDE_SKILL_DIR}/../../references/reports.md`.
