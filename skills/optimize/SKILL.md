---
name: optimize
description: Code and performance optimization - give a page link (web) or an app package (mobile) to scan it, get a summary, then optimize it; or audit API payloads vs the fields consumers use, front requests that should not happen, heavy pages, slow backend code, dead and duplicated code. Optional parts (api, front, back, dead) and filter (e.g. --orders).
argument-hint: "[<page URL> | <android package> [--flow maestro.yaml]] [api] [front] [back] [dead] [--<route-or-page-filter>] [path]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

Apply the rules of `${CLAUDE_SKILL_DIR}/../../SKILL.md` and `${CLAUDE_SKILL_DIR}/../../references/performance.md` (one section per part below). Read-only until the user approves the fixes; in link mode, giving the link is that approval (step 0). Measure before and after; anything not measured is reported as **not verified**.

0. **A page URL is given → link mode**: the link is the user's approval to optimize that page. Run the steps in order, without asking between them:
   1. **Scan**: `bash ${CLAUDE_SKILL_DIR}/../../scripts/page-scan.sh <url> --save-json <tmp>/before.json --report <tmp>/report.json` (Lighthouse: the standard page performance measure, same engine as Chrome DevTools and PageSpeed Insights). Lighthouse missing → ask once to allow `--allow-download`.
      - Blank page (`NO_FCP`) or login redirect → the page needs a session. Ask the user which way (a **test account**, never a production admin):
        - **test credentials** (any auth, session cookies included): `SISKA_SCAN_USER=… SISKA_SCAN_PASSWORD=… page-scan.sh <url> --login-url <login page url>`; the user can run it with `--ask` (hidden prompt) so the password never reaches the conversation;
        - **token**: `SISKA_SCAN_TOKEN=… page-scan.sh <url> --token-key <key>`; find the key in the front code (`localStorage.setItem(…)` after login), never guess it; an API-only bearer token → `SISKA_SCAN_HEADER='Authorization: Bearer …'`;
        - **manual** (captcha, 2FA): the user runs `page-scan.sh --login <url>`, logs in and **leaves the window open**; scans run inside it.
        Secrets go through environment variables only: never in a command argument, a file, the ledger, a commit, the report or the terminal summary. After the work, offer `page-scan.sh --logout`.
      - Desktop web app (back office, dashboard) → add `--desktop`; public or mobile-first site → default (mobile).
      - Development server warning → the numbers are not production ones: also scan a production build (`vite build && vite preview`, `next build && next start`) or staging, and base the plan on that.
      - A **browser MCP** (Playwright MCP, Chrome DevTools MCP) or browser skill is available → use it too, for what Lighthouse does not do: the requests made during user actions (filters, pagination, sort, opening a detail), console errors, and a performance trace of an interaction. Absent → continue with Lighthouse; propose installing one through the skills command only if actions must be measured.
      - Prefer a local or staging URL; a production URL gets one page load only.
   2. **Map the page to the code**: find the front route and component tree of that URL, and for each API call of the scan the backend route and controller (strip host and query string, match the route list).
   3. **Run the parts below on that page only** (api for its API calls, front for the page, back for its slow routes, dead for its files), then give the **summary**: score and metrics, weight, the tables of step 6, and the optimization plan, biggest gain first, each item with its expected gain and risk.
   4. **Apply the plan** right after the summary, on a new branch `perf/<page>` (never on the default branch, never pushed or merged). One item at a time, following step 7: change, run the tests and the build, commit (`perf: …`) so each item can be reverted alone. An item that breaks a test or the build is reverted and reported, never forced.
      **Not applied automatically, listed for confirmation instead**: database migrations or indexes, changes to a public or versioned API contract, adding or removing a dependency, deleting files or code reported as dead, anything touching auth, payments or production config.
   5. **Re-scan** the same URL with `page-scan.sh --report` and show **before → after** in the report page (a `compare` section and `before` values on the metrics) (score, LCP, TBT, transferred, requests, API bytes), the commits made, and the items waiting for confirmation. A gain that did not happen is reported as such.
   6. **Lock the gain**: the page has no entry in `.siska/perf-budget.json` → propose one (the new measure plus the tolerance); it has one → propose tightening it, then `perf-budget.sh . check <name> <metrics> --update-baseline` (`references/performance.md`, section Performance budgets). Only after the user says yes.
0b. **An app package or "mobile" is given → mobile mode** (React Native, Expo, native Android), same steps as the link mode, with the mobile tools:
   1. **Scan** on a booted device or emulator: `bash ${CLAUDE_SKILL_DIR}/../../scripts/mobile-scan.sh <package> [--flow <maestro.yaml>] --report <tmp>/report.json` (package: `android.package` in `app.json` / `applicationId` in `android/app/build.gradle`). It measures cold start, janky frames and frame times, memory, CPU and installed size with adb and dumpsys.
      - A **Maestro flow** that opens the screen to optimize (and logs in with a test account when needed) makes the frame figures about that screen; the project's existing flows (`.maestro/`) come first, otherwise write a short one for that screen. Credentials go in Maestro env vars (`maestro test -e USER=… -e PASSWORD=…`), never in the flow file.
      - No device → ask the user to start an emulator or plug a phone (`adb devices`); none possible → static analysis only, marked not measured.
      - Debug build or emulator warnings → the figures are indicative; base the plan on a release build on a real mid-range phone when possible.
      - iOS: no script; use Xcode Instruments (Time Profiler, Animation Hitches) on a release build, or measure on Android when the code is shared.
      - JS bundle: Expo Atlas (`EXPO_ATLAS=1 npx expo start`) or `npx expo export --platform android` sizes; `react-native-bundle-visualizer` for bare React Native.
   2. **Map the screen to the code** (Expo Router file, navigator screen, components, hooks), and its API calls to the backend routes.
   3. **Run the parts on that screen** (api, front = the screen's rendering, back, dead) with the mobile checks of `references/performance.md` (lists, images, JS-thread work, re-renders, animations, requests on focus), then the summary.
   4. **Apply the plan** as in the link mode (same branch, commits and exclusions), then **re-scan** with the same flow and show before → after.
1. **Scope**: parts `api`, `front`, `back`, `dead` (combinable); none = all. Filter: strip leading `--`, keep routes, pages and files whose path, name, controller or component contains it. Stack: `bash ${CLAUDE_SKILL_DIR}/../../scripts/detect-stack.sh .`
2. **api – payload vs consumers** (section "Payload"):
   - list the real routes with the framework (`php artisan route:list --json`, `bin/console debug:router`, route files, `/openapi.json`);
   - find every consumer: web, mobile, other services (path and API client function: fetch, axios, `useQuery`, SWR, RTK Query, generated clients), MCP tools, webhooks, jobs, external clients (public or versioned API). Unknown or external consumer → the field **cannot be removed**;
   - returned fields (API Resource, transformer, serializer, DTO, `select`, or `curl -s -o /dev/null -w '%{size_download} bytes %{time_total}s\n' <url>`) vs fields each consumer reads (property access, destructuring, props passed down, table columns); relations loaded but not returned or not used; pagination.
3. **front – useless requests and heavy pages** (sections "Front requests that should not happen", "Heavy pages"): requests per page load and per typical action, duplicated or repeated calls, calls for hidden UI, client-side N+1, polling, no debounce, sequential awaits; page weight (Lighthouse, bundle and chunk sizes), large imports, code splitting, lazy loading, images, fonts, re-renders, long lists.
4. **back – slow code** (section "Backend code"): profile the slow routes first; queries and HTTP calls in loops, repeated work, memory (whole tables or files), synchronous heavy work to move to a job, cache, indexes (`EXPLAIN`).
5. **dead – dead and duplicated code** (section "Dead and duplicated code"): run the tool already in the project, otherwise ask before downloading one; verify each candidate against dynamic use before listing it.
6. **Report, short** – only the tables of the parts run:
   - `Route | Consumers | Returned | Used | Unused fields | Payload now → estimated | Queries | Risk`
   - `Page | Requests on load (useless) | Transferred | JS | Main cause`
   - `Backend: Route/job | Time | Queries | Main cause`
   - `Dead/duplicate: File:line | Kind | Evidence | Safe to remove (yes/check)`
   - then the findings, biggest measured gain first: `file:line` · problem · measured impact · minimal fix.
   Deliver it as a visual report with the link, following `${CLAUDE_SKILL_DIR}/../../references/reports.md`.
7. **Fix, only after the user approves, one item at a time**, with the project's own mechanisms (API Resource, serializer, `select`, query cache, lazy import, framework image component, job/queue):
   - never remove a field another consumer reads; public or versioned API → add (new version, `fields=` parameter, page-specific endpoint), never remove silently;
   - measure the same request or page before and after, run the tests and the build, update the API documentation (`references/documentation.md`).
