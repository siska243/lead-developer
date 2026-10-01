# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [1.13.0] - 2026-09-30
### Added
- The developer's language: `settings language <code>|auto` (default `auto`, the language of the developer's messages). Answers follow it; generated project docs follow the project's existing docs language, else that language; code and commit messages stay in English. Claude Code: reminder from the prompt hook; other agents read the setting. Visual reports translate their interface words (en, fr, es, de, pt) from `"lang"`.
- `CLAUDE.md` (the project specification) translated to English.
- Micro-task mode, off by default: `settings micro on|off` (project or `--global`). Non-trivial tasks are split into 2–4 micro-tasks with one verifiable result each, announced, verified (tests, lint, diff) and reported one by one; sub-agent work follows a contract and is read and re-checked before it is integrated; tracked as `T<n>.1`… (`references/microtasks.md`). Claude Code: reminder injected by the prompt hook, even with the ledger off; other agents read the setting.
- API docs like API Platform: `api-docs.sh` builds the page from `templates/api-docs/page.html` – a bar in the project's colours (brand colour read from the front end's CSS variables, `tailwind.config` or `theme-color`, or `--brand-color`; `--logo`, `--font`; dark variant derived with `color-mix`) and exports (Postman collection, Postman environment, OpenAPI; copy on shared pages) above the Scalar reference themed with the same accent. `--spec-url` loads the live spec served by the app's generator; `*.postman_environment.json` and `openapi.json` are written next to the page. Colour, font and URL inputs are validated. On a shared page the exports use the viewer's download capability when offered, else copy the file; the page stays usable (exports) if the reference library cannot load.
- Interactive data model explorer: `data-model.sh --html` (file to open) and `--artifact` (page to share), from `templates/data-model/explorer.html` (Cytoscape.js, pinned). Zoom, pan, rotate, fit, search a table or a column, table sheet (columns, type, null, default, keys, indexes, relations both ways, clickable), focus on neighbours (1 or 2 levels, or only them), layouts, draggable tables, deep link `#table`, colour per domain, foreign keys without index dashed, "Issues only" filter, keyboard shortcuts, light/dark, phone width. Checked on a 229-table PostgreSQL schema (layout in about 2 s).

## [1.12.0] - 2026-09-30
### Added
- `/siska-lead-developer:api-docs` and `scripts/api-docs.sh`: from the project's OpenAPI 3 file, an interactive reference with a request client (Scalar, pinned version), a Postman v2.1 collection (Postman, Insomnia, Bruno; `{{baseUrl}}`, `{{token}}`, one folder per tag, bodies from examples or schemas), `api-structures.md` (per endpoint: parameters, request and response fields with type, required, default, allowed values, format, limits, example; `$ref` and `allOf` resolved), and a shareable read-only page. Flags 2xx responses without schema. Generator per stack in `references/documentation.md` (Scramble, FastAPI, NestJS, zod-to-openapi, drf-spectacular, springdoc, swag…).
- `/siska-lead-developer:data-model` and `scripts/data-model.sh`: the real schema (Laravel 11+ introspection, SQLite, or normalized JSON for other stacks) as `docs/data-model.md` with a Mermaid ER diagram and a table dictionary; flags tables without primary key and foreign keys without index.
- Report template: `diagram` sections (Mermaid, pinned version).

## [1.11.0] - 2026-09-30
### Added
- Performance budgets: `scripts/perf-budget.sh` (`run` measures every page and app of `.siska/perf-budget.json`, `check` compares a measure made elsewhere) fails when a metric passes its budget or drifts from its baseline (`.siska/perf/<name>.json`) by more than `tolerance_pct`; `--update-baseline` records a passing measure; visual report data. `check-code --perf`; `optimize` proposes a budget or a tighter one after an optimization; optional CI step.
- `page-scan.sh --metrics` and `mobile-scan.sh --metrics`: flat numbers for budgets (web: score, LCP, FCP, TBT, CLS, transferred, API weight, requests, duplicates; mobile: cold start, janky frames, frame p90, memory, CPU, size).
### Fixed
- `page-scan.sh` no longer counts CORS preflights as duplicate requests.

## [1.10.0] - 2026-09-30
### Added
- `scripts/secret-scan.sh`: blocks hardcoded secrets before every commit – private keys, AWS/GitHub/GitLab/Slack/Stripe/Google tokens, `sk-…` API keys, JWTs, passwords in connection URLs, `password`/`secret`/`api_key`/`token` literals, key and keystore files, tracked `.env`. Env references and placeholders pass; `siska:allow-secret` marks a reviewed false positive. Leaks are reported with their file.
- The commit gate refuses AI attribution (AI `Co-Authored-By:` trailer, "Generated with …") in commit messages and in `gh pr create/edit`; `install-git-hook.sh` also installs a `commit-msg` hook.
- `/siska-lead-developer:optimize [api] [front] [back] [dead]`: API fields consumers never read, front requests that should not happen (repeated, duplicated, for hidden UI, client-side N+1, no debounce), heavy pages (Lighthouse, bundle, images, code splitting), slow backend code (profiling, queries in loops, jobs, cache), dead and duplicated code (knip, jscpd, vulture…); fixes after approval, measured before and after, without breaking other consumers.
- Link mode: `/siska-lead-developer:optimize <page URL>` scans the page (`scripts/page-scan.sh`: Lighthouse score and metrics, weight per type, heaviest resources, API calls, requests made more than once, opportunities), maps it to the front and backend code, gives a summary and a plan, applies it on a `perf/<page>` branch (one commit per item, reverted if tests or build fail; migrations, API contract changes, dependencies, deletions, auth/payments wait for confirmation), then re-scans and shows before → after. Login pages: session header through `SISKA_SCAN_HEADER` only.
- Rules: mandatory doc comments for new or changed code and an up-to-date README (`references/documentation.md`); latest stable versions, end-of-life check and regular batched dependency updates (`references/dependencies.md`, `audit-package --outdated`); payload trimmed to what consumers use (`references/performance.md`).
- Mobile mode: `/siska-lead-developer:optimize <android package> [--flow maestro.yaml]` and `scripts/mobile-scan.sh`: cold start (`am start -W`, median of runs), janky frames and frame-time percentiles (`dumpsys gfxinfo`) during a Maestro flow or scrolls, memory, CPU, installed size, with warnings for debug builds and emulators; same report format. `references/performance.md` gains the mobile tools (Maestro, Flashlight, Expo Atlas, Xcode Instruments) and usual causes.
- `secret-scan.sh --history` (every commit of every branch) and `--range A..B` (a pull request's commits); findings show commit and file:line with values masked; `.siska/secrets-allow` lists reviewed locations already in the history. `check-code --history`.
- CI: `.github/workflows/checks.yml` for the plugin (secret scan of the pull request and of the history, script tests; actions pinned by commit SHA) and `templates/ci/` (GitHub Actions, GitLab CI) to add the same checks to a project's existing pipeline.
- Visual reports: `scripts/report.sh` + `templates/report/` turn a small JSON into one clean page (verdict, metrics, tables, findings, before → after; light/dark, phone width, data rendered as text only). Every command result is delivered as that page (artifact in Claude Code, `.siska/reports/*.html` elsewhere) plus a short terminal summary with the link last (`references/reports.md`).
- `page-scan.sh --login <url>`: creates a session in a dedicated Chrome profile that later scans reuse – with a token (`SISKA_SCAN_TOKEN` + `--token-key`, stored in localStorage), test credentials (`SISKA_SCAN_USER` / `SISKA_SCAN_PASSWORD`, or `--ask` for a hidden prompt; the login form is filled and submitted by `scripts/browser-session.js` over the Chrome DevTools protocol, no new dependency), or manually in a visible Chrome left open, which scans connect to (`--port`). Credentials or token given on the scan itself (`--login-url`) log in and measure in the same headless Chrome, so apps using session cookies work. `--logout` closes and deletes the session; a hung Lighthouse and its Chrome are stopped before the retry; dev servers are measured with DevTools throttling from the start. `--report` writes the report data, `--save-json` keeps the raw Lighthouse report. Warnings for blank pages (`NO_FCP`) and development servers; a hanging scan is stopped after 180 s and retried with DevTools throttling; Lighthouse 13 insights are read.
- Terminal: spinner during long scans and coloured `OK` / `WARN` / `BLOCK` labels, only on a real terminal (`NO_COLOR` respected).
### Changed
- The secret scan runs even when the gate is off (`settings gate off`) or skipped (`SISKA_SKIP_GATE=1`); those now skip tests and lint only.
- The secret scan ignores quoted variable references (`PASSWORD="$VAR"`).
- `check-project.sh` uses `secret-scan.sh` (wider patterns, file names in the report).

## [1.9.0] - 2026-09-28
### Added
- `/siska-lead-developer:settings` and `scripts/settings.sh`: turn the commit gate (`gate`) or the request ledger hooks (`ledger`) on/off per project (`.siska/settings`) or globally (`~/.siska/settings`), without disabling the plugin; a disabled gate is announced on every commit.

## [1.8.1] - 2026-09-28
### Changed
- Lower token use of the request ledger: closed tickets are archived automatically by the prompt hook (`.siska/requests-archive.md`), new tickets are appended without reading the file, updates read only the ticket's lines, shorter hook text with the last ID, compact end-of-response table.

## [1.8.0] - 2026-09-28
### Added
- Request ledger enforced in the Claude Code plugin (`scripts/ledger-hook.sh`): each message injects the open tickets and the ledger format; the response cannot end until `.siska/requests.md` was updated (max 2 reminders, git repositories only).
### Fixed
- `SKILL.md` states the ticket ID format again (`T1`, `T2`…).

## [1.7.1] - 2026-09-28
### Added
- Explicit commit gate skip: `SISKA_SKIP_GATE=1 git commit …` (announced on stderr); the agent uses it only when the user asks in the current message and reports it.

## [1.7.0] - 2026-09-28
### Added
- Commands for every Skills-compatible agent: `install.sh` generates `siska-audit-route`, `siska-check-code`, `siska-document`, `siska-skills`, `siska-tickets`, `siska-mcp`, `siska-help` with absolute paths and standard frontmatter only (recognized for Codex, GitHub Copilot, OpenCode).
- `scripts/install-git-hook.sh`: native git pre-commit commit gate for any agent; never overwrites an existing hook or hook manager; harmless if the skill is later removed.
- `compat/README.md`: install, skills directory, command call and commit gate per agent.
### Changed
- Commit gate message no longer names one agent.

## [1.6.0] - 2026-09-28
### Added
- Skill and MCP orchestration (`references/orchestration.md`): needed capabilities → installed → search (skills.sh, agent marketplaces, official MCP Registry) → vetting → consent → install; refusal is final; Siska's rules override any skill.
- `scripts/list-capabilities.sh`: skills and MCP servers installed for AI coding agents (skill dirs, plugins, MCP configs).
- `scripts/vet-skill.sh`: static security review of a skill/plugin before install (scripts, hooks, MCP servers, allowed-tools, network, secrets, destructive or hidden instructions).
- `/siska-lead-developer:skills [list|find|vet|install]`.
- High-risk action rule: impact and rollback, explicit confirmation, or refusal.

## [1.5.0] - 2026-09-28
### Added
- Mandatory feature documentation (`references/documentation.md`): functional page, then technical (API calls, data, jobs, security), verified against the code, human-sounding; part of the delivery checklist.
- `/siska-lead-developer:document [--functional|--api|--code]`.
- OpenAPI guidance per stack (FastAPI, Scramble/Scribe, API Platform/Nelmio, @nestjs/swagger, swagger-jsdoc) and spec lint with `@redocly/cli`.

## [1.4.0] - 2026-09-28
### Added
- Commit gate: plugin `PreToolUse` hook runs `scripts/pre-commit-gate.sh` on every `git commit` and blocks it when tests, lint, secret or `.env` checks fail.
- `/siska-lead-developer:check-code` command.
- `check-project.sh --run-lint`: Pint, PHPStan, `composer lint`, npm `lint`/`typecheck` scripts, Ruff.
- `.siska/checks`: project-declared check commands, replacing auto-detection.
- `check-project.sh --scope front,back,mobile` and `check-code --front/--back/--mobile`; `.siska/checks` lines can be tagged `front:` / `back:` / `mobile:`; a scope with no command is reported as not verified.

## [1.3.0] - 2026-09-28
### Added
- Request ledger (`references/requests.md`): every request gets an ID (T1…), priority (P1–P3) and status (todo, in progress, done, needs info, cancelled), stored in `.siska/requests.md`; duplicate check before redoing a done request; `t<n>` messages update a ticket; summary table at the end of each response.
- `/siska-lead-developer:tickets` command to show or update tickets.
- Uniformity rules: one way to do one thing, project linters/formatters on changed files, no second library for the same job.
- Design system applied to the letter: tokens only, one component per purpose, same pattern for the same interaction.
- Human-sounding writing for comments, docs, commits, PR and UI copy (humanizer skill when available).
- Plain-language explanation of the plan before acting.
- Sub-agent guidance (when they save context or run in parallel, cheaper models for simple tasks) and token economy rules.
### Changed
- `SKILL.md` condensed from ~1150 to ~600 words; tools, sub-agents and token rules moved to `references/agents.md`.

## [1.2.0] - 2026-09-28
### Added
- `audit-package`: maintenance status of direct dependencies (deprecated, abandoned, archived, stale) and unused dependency detection (knip, composer-unused, deptry) with removal only after approval.
- `security-audit.sh`: reports abandoned Composer packages (Composer >= 2.7).

## [1.1.1] - 2026-09-28
### Fixed
- `install.sh` refuses to install a copy into `.claude/skills` when the Claude Code plugin is installed.
### Changed
- README: `/plugin` install/uninstall steps and the marketplace source conflict error.

## [1.1.0] - 2026-09-28
### Added
- Claude Code plugin (`.claude-plugin/`) with commands `:help`, `:audit-route [--filter]`, `:audit-package [--outdated]`, `:mcp`.
### Changed
- `siska-lead-mcp` replaced by `/siska-lead-developer:mcp`; `install.sh` now installs the main skill only (other agents) and still removes the old entry on `--uninstall`.
- README shortened.

## [1.0.0] - 2026-09-28
### Added
- `SKILL.md`: Lead Developer identity, priorities, absolute rules, workflow, reference loading, tools/team mode, red flags.
- References: workflow, TMA, new project, clean code, git, security, dependencies, testing, performance, design system, UX, motion design, MCP.
- Scripts: `detect-stack.sh`, `security-audit.sh`, `check-project.sh`, `install.sh`, shared `lib.sh`, self-tests.
- MCP templates: TypeScript server (stdio + stateless Streamable HTTP, OAuth resource server, scope-checked tool, tests), OAuth guide, client config.
- `siska-lead-mcp` entry skill and `compat/claude-code.md`.
- `install.sh --uninstall`: removes only symlinks or directories declaring the expected skill name; keeps backups.
