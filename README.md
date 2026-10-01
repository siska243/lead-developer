# Siska Lead Developer

Makes your AI coding agent work like a **senior Lead Developer**: zero regression, security first, nothing invented, scope respected, tests before "done".

![How Siska Lead Developer works: a request goes through understand, plan in micro-tasks, implement, verify and deliver, guarded on every commit by tests, linters, a secret scan and the same checks in CI; it produces visual reports, API docs with a Postman export, a data model explorer and performance budgets, with Claude Code, Codex, GitHub Copilot or OpenCode.](docs/images/overview.svg)

## Commands

| Command | What it does |
|---------|--------------|
| `/siska-lead-developer:help` | Lists every command |
| `/siska-lead-developer:siska-lead-developer <task>` | Any development task (ticket, bug, maintenance, review, new project, UI). Also triggers on its own. |
| `/siska-lead-developer:audit-route` | Security audit of every API route |
| `/siska-lead-developer:audit-route --orders` | Audit of the routes that contain `orders` |
| `/siska-lead-developer:audit-package` | Dependencies: vulnerabilities, abandoned or unmaintained packages, unused packages (removed after your approval) |
| `/siska-lead-developer:audit-package --outdated` | Same, plus outdated packages |
| `/siska-lead-developer:optimize` | Code optimization: API fields the front end never uses, useless front-end requests, heavy pages, slow backend code, dead and duplicated code. Fixes after your approval |
| `/siska-lead-developer:optimize https://app.local/orders` | Give a page link: it scans the page, gives you a summary and a plan, applies it on a `perf/` branch (risky items wait for your yes), then shows before → after |
| `/siska-lead-developer:optimize com.company.app --flow .maestro/orders.yaml` | Mobile: measures the app on a phone or an emulator (cold start, janky frames, memory), summary, plan applied, before → after |
| `/siska-lead-developer:optimize front --orders` | Only some parts (`api`, `front`, `back`, `dead`, combinable), only what matches `orders` |
| `/siska-lead-developer:api-docs` | API docs like API Platform, in your site's colours: read and send requests, served by the app or shared, exports (Postman collection and environment, OpenAPI for Insomnia, Bruno, Hoppscotch), fields sent and returned with type, required, default, allowed values |
| `/siska-lead-developer:data-model` | Data model: interactive explorer (zoom, pan, rotate, search, focus on a table and its neighbours) and docs with an ER diagram; flags tables without a primary key and foreign keys without an index |
| `/siska-lead-developer:mcp <what to expose>` | Add or audit an MCP server |
| `/siska-lead-developer:check-code` | Pre-commit check: tests, linters, hardcoded secrets and keys, `.env`. The commit is refused if anything fails |
| `/siska-lead-developer:check-code --front` | Same, front end only (also `--back`, `--mobile`, combinable) |
| `/siska-lead-developer:document <feature>` | Documentation: functional, then technical (API calls…) · `--functional`, `--api`, `--code` |
| `/siska-lead-developer:skills` | Installed skills and MCP servers · `find <need>` · `vet <source>` · `install <source>` (only after your yes) |
| `/siska-lead-developer:settings gate off` | Turns the pre-commit check off / on (`gate on`); `ledger off` for request tracking; `--global` for every project |
| `/siska-lead-developer:settings language fr` | Language the agent answers you in and writes reports in (`auto`, the default, follows the language of your messages); code, database, docs and commits are always English |
| `/siska-lead-developer:settings micro on` | Micro-task mode: every task split into 2 to 4 short micro-tasks, announced, verified and summarized one by one; sub-agent work is validated before integration · `micro off` to stop |
| `/siska-lead-developer:tickets` | Open requests (T1, T2…) with status and priority · `--all` for every request |
| `/siska-lead-developer:tickets t2 done` | Change a ticket: `done`, `todo`, `progress`, `cancel`, `info`, `P1`–`P3`, or add an instruction |

Audits change nothing: they produce a report, then ask you what to fix.

## Commits blocked when checks fail

The plugin installs a hook: before every `git commit` the agent runs, it runs the tests, the linters and the secret scan. If one of them fails, **the commit is blocked** and the reason is shown.

- Commands are detected automatically:
  - PHP: `composer test`, `php artisan test`, Pest, PHPUnit, Pint, PHPStan;
  - JS/TS: the `test`, `lint` and `typecheck` scripts of `package.json`;
  - Python: `pytest` and `ruff`.
- Automatic grouping:
  - **back**: PHP, Python, server-side Node;
  - **front**: React, Next.js, Vue, Vite…;
  - **mobile**: Expo, React Native.
- To choose exactly what runs, create `.siska/checks` at the project root with one command per line. A line can be tagged: `front: npm run lint`, `back: php artisan test`.
- The pre-commit hook always checks everything. `check-code --front` checks one part while you work.
- **Turn the check off** without disabling the plugin (see also the micro-task mode below): `/siska-lead-developer:settings gate off`, then `gate on` to turn it back on. The setting applies to the project (`.siska/settings`), or to every project with `--global`. While it is off, every commit shows a warning. Request tracking is turned off the same way: `settings ledger off`.
- **Skip the check** for one commit:
  - ask the agent ("skip the check for this commit"): it commits with `SISKA_SKIP_GATE=1 git commit …` and says so in its report. It never does it unless you ask;
  - or run `SISKA_SKIP_GATE=1 git commit -m "…"` yourself. With the git hook (other agents), `git commit --no-verify` also works;
  - commits you make in your own terminal do not go through the Claude Code plugin hook.
- If the checks take longer than 10 minutes, the hook stops without blocking: run `/siska-lead-developer:check-code` before committing.

### No secret in the code

Before every commit, `scripts/secret-scan.sh` looks through the added lines and new files for:
- private keys, AWS, GitHub, GitLab, Slack, Stripe and Google tokens, `sk-…` API keys, JWTs;
- passwords in connection URLs (`mysql://user:<password>@host`);
- `password`, `secret`, `api_key`, `token`… variables given a hardcoded value;
- key files (`.pem`, `.key`, `.p12`, `id_rsa`…) and `.env` files tracked by git.

This check **always** runs, even with `gate off` or `SISKA_SKIP_GATE=1`: a committed key stays in the git history. References to environment variables (`env("DB_PASSWORD")`, `process.env.X`, `${VAR}`) and example values (`<your-token>`) pass. A reviewed false positive (a test fixture) is marked with a `siska:allow-secret` comment on its line. A key that was already committed is compromised: rotate it.

### Git history and CI

- `bash scripts/secret-scan.sh . --history` (or `/siska-lead-developer:check-code --history`) scans **every commit of every branch**. A key committed long ago, even deleted since, can still be read in every clone: rotate it. Values are masked in the output (`AKIA****`).
- A false positive already in the history is declared in `.siska/secrets-allow` with its reason: `<commit> <file>:<line>`.
- **CI**: local hooks can be bypassed (`--no-verify`, another machine, an edit on the web). `templates/ci/github-actions.yml` and `templates/ci/gitlab-ci.yml` run the secret scan on every pull request (the request's commits and the whole history), then the tests and the linters. Siska offers to add them to the project's existing CI, never without your approval. This repository has its own: `.github/workflows/checks.yml`.

### No AI co-author

Commit messages and pull request descriptions describe the technical change, with no AI tool `Co-Authored-By:` line and no "Generated with …". The hook refuses such commits (and `gh pr create/edit` in Claude Code); the git `commit-msg` hook does the same for other agents. A human co-author is still accepted.

## Visual reports

Every command result (audits, `check-code`, `optimize`, `document`) comes in two forms, with the same figures:
- **a report page**, clear, in light or dark theme and readable on a phone: verdict, key figures, tables, findings ranked by severity, before → after, and what could not be verified. In Claude Code it is a private artifact; with other agents, a `.siska/reports/<command>-<date>.html` file to open in a browser;
- **a short summary in the terminal**, with colours and a spinner during long scans when it runs in a real terminal, and **the report link on the last line**.

Reports never contain a secret, a session cookie or personal data. Data format: `templates/report/README.md`.

### Pages behind a login

`optimize <link>` measures the page with Lighthouse, the standard tool and the same engine as Chrome DevTools and PageSpeed Insights. If the page needs a login, create a session once, the way you prefer (a **test account**, never a production admin):

```bash
# login and password: log in, then measure in the same Chrome (works with session cookies too)
SISKA_SCAN_USER='qa@example.com' SISKA_SCAN_PASSWORD='…' bash scripts/page-scan.sh https://app.local/orders --login-url https://app.local/login
bash scripts/page-scan.sh https://app.local/orders --login-url https://app.local/login --ask   # hidden prompt: the password never goes through the agent
# token: stored in localStorage, where your front end keeps it after login
SISKA_SCAN_TOKEN='…' bash scripts/page-scan.sh https://app.local/orders --token-key auth_token
# manual (captcha, 2FA): a visible Chrome opens, you log in and LEAVE THE WINDOW OPEN
bash scripts/page-scan.sh --login https://app.local/orders
bash scripts/page-scan.sh --logout                                # closes and deletes the session
```

The session lives in a private Chrome profile outside the project (`~/.cache/siska/chrome-profile`). Session cookies, which have no expiry date, die when Chrome closes: that is why logging in and measuring happen in the same Chrome, and why each scan copies the session of the open window into a throwaway headless Chrome. The token and the password only go through environment variables: they are never printed, written to a file or put in the report. If you give a token or a password to the agent in the chat, it stays in the conversation history: prefer `--ask`, or a short-lived test token. When a browser MCP (Playwright MCP, Chrome DevTools MCP) is installed, it also measures the requests made during user actions: filters, sorting, pagination. On a development server (Vite, `next dev`), a warning reminds you that the figures are not production figures.

### Performance budgets

So that your pages do not get heavy again, little by little:

```json
// .siska/perf-budget.json (committed)
{ "tolerance_pct": 10,
  "pages": { "orders": { "url": "http://localhost:4173/order-v2", "desktop": true,
             "budget": { "api_kb": 800, "transferred_kb": 1500, "lcp_ms": 2500, "duplicate_requests": 0 } } },
  "apps":  { "android": { "package": "com.company.app", "flow": ".maestro/orders.yaml",
             "budget": { "cold_start_ms": 1500, "janky_pct": 5 } } } }
```

- `bash scripts/perf-budget.sh . run`, or `/siska-lead-developer:check-code --perf`, measures every page and every app, and **fails** when a limit is passed.
- It also fails when a measure gets more than 10% worse than the **baseline** (`.siska/perf/<name>.json`, the last accepted measure), even under the limit.
- After an optimization, `optimize` offers to tighten the budget and record the new baseline (`--update-baseline`), with your approval.
- In CI: after the build and the app start, the `perf-budget.sh . run` step blocks the pull request that makes a page heavier.
- Always measure in the same conditions: a production build or staging for the web (never the dev server), a release build on the same phone for mobile.

### Mobile apps

The same command works for React Native, Expo and Android, with the standard mobile tools, since Lighthouse only measures the web:

```bash
bash scripts/mobile-scan.sh com.company.app                                  # cold start, smoothness, memory, CPU, size
bash scripts/mobile-scan.sh com.company.app --flow .maestro/orders.yaml     # measure during a Maestro flow (a given screen, a login)
```

The script uses `adb` and `dumpsys` on a plugged-in phone or an emulator, and Maestro to replay a flow. A test account's credentials go in Maestro variables (`-e`), never in the flow file. It warns you when the figures are only indicative: debug build or emulator. For real figures, use a release build on a mid-range phone. iOS is measured with Xcode Instruments. The weight of API responses is checked in the code and the backend, as for the web.

## Micro-task mode

To avoid the gaps and silent errors of a long task done in one go:

```text
/siska-lead-developer:settings micro on            # this project
/siska-lead-developer:settings --global micro on   # every project
/siska-lead-developer:settings micro off
```

When it is on:
- every non-trivial task is **split into 2 to 4 micro-tasks**, each with one verifiable result: a function and its test, an endpoint and its request test, a component and its states;
- **before** each micro-task, the agent explains in 2 or 3 lines what it will do, why, and how it will check it;
- **after** it, the agent verifies (tests, linters, a read of the diff) and summarizes the result with the evidence; the next one never starts on a broken micro-task;
- an independent micro-task can go to a **sub-agent**, with a precise contract (files, acceptance criteria). The lead **reads its whole diff and re-runs the checks before integrating it**; nothing is integrated unread;
- micro-tasks are tracked in the ticket: `T12.1`, `T12.2`…;
- a trivial fix stays a single step.

Off by default. In Claude Code, the reminder is injected on every message. Other agents read the `micro-tasks` setting in `.siska/settings`, which `bash scripts/settings.sh . micro on` also writes. Full rules: `references/microtasks.md`.

## Your language

The agent **talks to you** in your language, and **writes the project** in English.

- It answers in the language of your messages, or in the one you set: `/siska-lead-developer:settings language fr` (`--global` for every project, `language auto` to go back to the default).
- Visual reports are written in your language, and their interface words follow it (English, French, Spanish, German and Portuguese; others fall back to English).
- **Everything in the project is English, always**: variables, functions, classes, files, routes, tables, columns, migrations, comments, doc comments, documentation and commit messages, following the stack's senior conventions. `createOrder()`, `orders.delivery_date`, never `creerCommande()` or `date_livraison`.
- Text your app shows its users (labels, messages, emails) is in your product's language, through its i18n files, with English keys.
- Existing French names are never renamed silently: that would break queries, API clients and mobile apps. New code is in English, and the rename is proposed as a separate ticket with a compatible migration.

In Claude Code, a set language is reminded on every message. Other agents read `language` in `.siska/settings`.

## Skills and MCP

Siska uses the skills and MCP servers already installed first, and loads only the ones useful for the task. When one is missing:
1. it searches for it, with `npx skills find` for skills and the official registry for MCP servers;
2. it analyses it without running it (`scripts/vet-skill.sh`: scripts, hooks, network access, secrets, dangerous commands, hidden instructions);
3. it asks for your approval: yes, no, or more information.

A refusal is final, and Siska carries on without the skill when it can. For risky actions (production, deletion, `DROP`, deployment, DNS…), it shows the impact and the rollback, then asks for confirmation, or refuses.

Examples:
- "I need a Kubernetes skill": it checks what is installed, searches, analyses, then offers you 1 to 3 skills to install.
- "Optimize my Docker setup for production": it combines Docker, security and performance expertise in one plan.
- "Deploy this application": a high-risk action; it shows the impact and the rollback, and waits for your confirmation.

## Documentation

Every new or changed feature is documented in the same ticket. Without its documentation, the ticket is not done.

1. **Functional**: what it is for, who uses it, the user journey, the rules, the screens, the errors.
2. **Technical**: the API calls (route, authentication, parameters, responses, errors, examples), the data, the jobs, the permissions.

The code is documented too: every new or changed class, public function, endpoint, job or script gets its doc comment (purpose, parameters, return value, errors, side effects), and comments explain the *why*. The README stays true: install, configure (environment variable names), run, test, deploy.

Everything is checked against the code, nothing is invented, and the text reads as if a person wrote it. The page goes in the project's docs folder, or in `docs/features/` when there is none. The OpenAPI file is updated when it exists.

## API documentation and data model

### API docs like API Platform (`api-docs`)

**In your site's colours**: the brand colour is read from your front end (CSS variable `--primary` or `--brand`, `tailwind.config`, `theme-color`), with your logo and font when you give them. Siska says where the colour came from; when it finds none, it stays neutral. Light or dark theme follows the reader's.

**Exports in the page**: Postman collection, Postman environment (`baseUrl`, and an empty `token` to fill in on your side) and OpenAPI. Insomnia, Bruno and Hoppscotch import these files. On a shared page (artifact), the exports offer the file for you to confirm, or copy it when downloads are not available.

**Served by your app**, like API Platform: the files go in `public/docs/api/`, and `--spec-url /docs/api.json` makes the page read the live spec from the generator, so it is always up to date. Siska asks whether the docs must stay behind your authentication or out of production: internal API docs have no place on the public internet.

From the project's OpenAPI file, three things:
- **an interactive page** (`index.html`): every route with what it accepts and what it returns, a **Test Request** button and an API client to send real requests, with your token typed in the page and never stored;
- **a Postman collection** (`*.postman_collection.json`), to import in Postman, Insomnia or Bruno: one folder per group, example bodies, `{{baseUrl}}` and `{{token}}` variables;
- **the API data structures** (`api-structures.md`): for each route, the parameters, the fields to send and the fields returned, with type, required or not, default value, allowed values, format, limits and an example.

To share the docs, publish them as a page (artifact): it can be read anywhere, but cannot send requests, which a shared page is not allowed to do. Share the collection too. To test the API, open `index.html` or import the collection.

**Adapted to your stack**: when the project has no OpenAPI file, Siska offers your stack's generator, which reads your real validation rules and resources. It installs it only after your approval:

| Stack | Generator |
|---|---|
| Laravel | Scramble (types, defaults and enums read from FormRequests and API Resources) |
| FastAPI | built in (`/openapi.json`) |
| Symfony | API Platform or NelmioApiDocBundle |
| NestJS | `@nestjs/swagger` |
| Express / Fastify | `zod-to-openapi` (when you validate with Zod) or `@fastify/swagger` |
| Django REST | drf-spectacular |
| Spring Boot | springdoc-openapi |
| Go | swag |

When your repository already has a Postman, Insomnia or Bruno collection, that one is updated.

```bash
bash scripts/api-docs.sh openapi.json --out docs/api --base-url http://localhost:8000/api --project ../my-front-end
bash scripts/api-docs.sh openapi.json --out public/docs/api --spec-url /docs/api.json --brand-color '#0e7c66' --logo public/logo.svg
```

### Data model (`data-model`)

Reads the **real database schema**, read-only, never the rows: tables, columns, types, default values, keys, indexes and relations.

**The interactive explorer** (`docs/data-model.html`, also shareable as a page) is built for large schemas: hundreds of tables.
- Zoom with the mouse wheel or a pinch, pan with the mouse, rotate (⟲ ⟳), a button to fit everything.
- Search a table or a column, then click it: its columns (type, null, default, key), its indexes and its relations both ways, clickable.
- **Focus** on a table and its neighbours, 1 or 2 levels deep, or only them. Several layouts, draggable tables, direct link `…/data-model.html#orders`.
- One colour per domain; foreign keys without an index are dashed orange, and the "Issues only" filter isolates the tables to fix.
- Shortcuts: `/` search, `+` `-` zoom, `0` fit, `[` `]` rotate, `Esc` clear.

It also writes `docs/data-model.md` (Mermaid ER diagram and the full dictionary) and a visual report. It flags tables without a primary key and **foreign keys without an index**. PostgreSQL does not create those automatically, and their absence slows joins and deletes.

- Laravel 11+: the framework's own introspection, on the configured connection.
- SQLite: `--sqlite file.db`.
- Other stacks (Prisma, Django, Doctrine, TypeORM, Rails…): the schema is exported with the project's own tool, then passed with `--from-json`.
- More than 60 tables: one static diagram per domain, with `--only 'order|client'`.

When the configuration points to a production database, Siska asks before connecting to it.

```bash
bash scripts/data-model.sh . --html docs/data-model.html --markdown docs/data-model.md
```

## Up-to-date technologies and dependencies

- A new project or a new dependency starts on the latest stable version (LTS for runtimes and frameworks), checked on the registry at the time of the choice.
- End-of-life versions (PHP, Node, Python, Laravel, React Native…) are flagged with an upgrade plan.
- `/siska-lead-developer:audit-package --outdated` is offered when a ticket touches dependencies, on a project not checked for a month, and before a release: security fixes right away, patch and minor versions grouped, major versions one by one. Nothing is updated without your approval.

## Request tracking

Each request gets a number (`T1`, `T2`…), a priority (`P1` urgent, `P2` normal, `P3` minor) and a status:
⬜ to do · 🔄 in progress · ✅ done · ❓ needs information · ❌ cancelled.

- Write `t3 <instruction>` to add to ticket T3, and `t2 P1` to change its priority.
- A new request does not replace the previous ones: it joins the queue.
- A request already done is not done again: the agent asks you what to improve.
- Every answer ends with the ticket table.
- Tracking is stored in `.siska/requests.md`, at the project root. You decide whether to commit it or add it to `.gitignore`.
- **Enforced by the Claude Code plugin**:
  - on every message, the agent receives the list of open tickets and the format to follow;
  - it cannot finish its answer without updating `.siska/requests.md`, with at most 2 reminders to avoid a loop.

  This only works inside a git repository. Codex, Copilot and the other agents have no such hooks: for them, only the skill's rule applies.

## Install (Claude Code)

In Claude Code:

```text
/plugin marketplace add siska243/lead-developer
/plugin install siska-lead-developer@siska
```

Or from the terminal:

```bash
claude plugin marketplace add siska243/lead-developer
claude plugin install siska-lead-developer@siska
```

Error `Cannot add marketplace "siska": its network source differs…`: the `siska` catalogue is already declared from another source (a local clone, for example). Run `/plugin marketplace remove siska`, then try again.

From a local clone, replace `siska243/lead-developer` with the folder's path. Then restart Claude Code (or run `/reload-plugins`) and type `/siska-lead-developer:help`.

## Update

Two commands, in this order: the first fetches the up-to-date catalogue from GitHub, the second installs the new version of the plugin.

```bash
claude plugin marketplace update siska
claude plugin update siska-lead-developer@siska
```

Then **restart Claude Code**, or type `/reload-plugins` in an open session. Until you do, the session keeps the old version, hooks included.

To check the installed version:

```bash
claude plugin list          # siska-lead-developer@siska · Version: …
```

In Claude Code you can also go through `/plugin`, **Installed** tab, then `siska-lead-developer`.

With an install from a local clone: `git pull`, then `/reload-plugins`.

## Disable and enable

Disabling keeps the plugin installed: its commands, rules and hooks (pre-commit check, request tracking) stop until you enable it again.

```bash
claude plugin disable siska-lead-developer@siska
claude plugin enable siska-lead-developer@siska
```

- `--scope user|project|local` chooses where the setting applies: for you everywhere, for everyone on this project, or only your copy of this project. Without it, the scope of the install is detected.
- In Claude Code: `/plugin`, **Installed** tab, `siska-lead-developer`, then **Disable** or **Enable**.
- Then restart, or type `/reload-plugins`.

To turn off only one part, without disabling the plugin:
- the pre-commit check: `/siska-lead-developer:settings gate off`, then `gate on`;
- request tracking: `/siska-lead-developer:settings ledger off`, then `ledger on`;
- `--global` applies the setting to every project.

The secret scan and the AI co-author block stay on with `gate off`. Only disabling the plugin stops them.

## Uninstall

In Claude Code: `/plugin`, **Installed** tab, `siska-lead-developer`, then **Uninstall**.

Or from the terminal:

```bash
claude plugin uninstall siska-lead-developer@siska
claude plugin marketplace remove siska      # also removes the catalogue
```

## Codex, GitHub Copilot, OpenCode and other agents

```bash
git clone https://github.com/siska243/lead-developer && cd lead-developer
bash scripts/install.sh                               # into ~/.agents/skills
bash scripts/install-git-hook.sh /path/to/project     # pre-commit + commit-msg hooks: checks, secrets, AI co-author
```

- The main skill and its commands are installed as `siska-lead-developer`, `siska-api-docs`, `siska-audit-package`, `siska-audit-route`, `siska-check-code`, `siska-data-model`, `siska-document`, `siska-help`, `siska-mcp`, `siska-optimize`, `siska-settings`, `siska-skills` and `siska-tickets`.
- To call a command:
  - Codex: `$siska-check-code`, or `/skills`;
  - Copilot: select or mention `siska-check-code`.
- For a single project: `bash scripts/install.sh --target /path/to/project/.agents/skills`.
- The git hook blocks every commit in the repository, made by an agent or by you. It never replaces an existing hook, nor husky or lefthook: in that case, it prints the line to add.
- Details per agent: `compat/README.md`.

**Update** (Codex, Copilot, OpenCode…):

```bash
cd lead-developer && git pull
bash scripts/install.sh --force        # or --target <folder> if you used it
```

`--force` replaces the install and keeps the old one as `*.bak.<date>`. With `--link`, the main skill follows `git pull`, but the commands are generated: run `install.sh --force --link` again to get new ones. Then restart the agent's session.

**Disable**: these agents have no common switch for it. Use your agent's skill settings if it has some; otherwise uninstall, and install again later:

```bash
bash scripts/install.sh --uninstall                            # removes the skill and its commands
bash scripts/install-git-hook.sh /path/to/project --uninstall  # removes the pre-commit check
```

To turn off only the pre-commit check on a project: `bash scripts/settings.sh /path/to/project gate off`. The secret scan and the AI co-author block stay on.

**What changes outside Claude Code:**
- The scripts work everywhere, with any agent or by hand: scans, budgets, API docs, data model, reports.
- **Reports** and pages (API docs, data model explorer) are **HTML files** to open in a browser (`.siska/reports/`, `docs/`), not shared artifacts.
- The **pre-commit check** goes through the git hook: it also blocks commits made by hand.
- **Request tracking** (T1, T2…) is a rule the agent follows. Only Claude Code enforces it, with its session hooks.
- Browser MCP servers (Playwright, Chrome DevTools) are used when your agent has them configured.

**Do not use this script for Claude Code**: use the plugin. The script refuses to install into `.claude/skills` when the plugin is already there, to avoid a duplicate.

Options: `--link` (symlink), `--force` (replace, keeping a backup), `--dry-run` (preview).

## Scripts you can run by hand

```bash
bash scripts/detect-stack.sh <project>                 # the real stack
bash scripts/security-audit.sh <project> [--outdated]  # dependency audit
bash scripts/check-project.sh <project> [--run-tests]  # pre-delivery check
bash scripts/secret-scan.sh <project> [--history]      # hardcoded secrets and keys in the changes (or the whole history)
bash scripts/page-scan.sh <url> [--report data.json]   # weight, requests, API calls and duplicates of a page (Lighthouse)
bash scripts/page-scan.sh --login <url>                # log in once to scan pages behind a login
bash scripts/mobile-scan.sh <package> [--flow f.yaml]  # performance of an Android app (adb, Maestro)
bash scripts/perf-budget.sh . run [--update-baseline]  # performance budgets of pages and apps
bash scripts/api-docs.sh openapi.json --out docs/api   # interactive docs, Postman collection, API data structures
bash scripts/data-model.sh . --html docs/data-model.html   # interactive schema explorer (+ --markdown)
bash scripts/report.sh data.json --out r.html --standalone   # visual report
bash scripts/settings.sh . [gate|ledger|micro on|off]  # turn automations on or off
```

## Developing the skill

```bash
bash tests/scripts.test.sh
cd templates/mcp/server && npm install && npm test
claude plugin validate .
```

Layout:
- `SKILL.md`: the main rules;
- `references/`: details loaded on demand;
- `skills/`: the `:xxx` commands;
- `scripts/`;
- `docs/images/`: the README illustration;
- `templates/`: `mcp/` (MCP server), `report/` (visual reports), `api-docs/` (API docs page), `data-model/` (schema explorer), `ci/` (CI jobs);
- `compat/`: layers specific to each agent.

See `CONTRIBUTING.md`. MIT license.
