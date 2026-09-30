# Performance

Measure before optimizing. Never claim "fast" without evidence. Optimize on observations or real technical risks, not speculation.

## Look for
| Layer | Problems |
|-------|----------|
| Database | N+1 (eager load: `with()`, `select_related`, joins), missing indexes on filters/joins/sorts, `SELECT *` on big tables, no pagination, queries in loops, long transactions |
| API | Useless calls, sequential calls that could be parallel, big payloads (fields not needed), no compression, no cache headers where safe |
| Backend | Heavy synchronous work in requests (move to queues/jobs), memory leaks, loading whole files/tables in memory |
| Cache | Missing where data is read-heavy and stable; stale data or missing invalidation where it exists |
| Frontend | Useless re-renders (unstable props, context too wide), excessive bundle, unoptimized images, no lazy loading, layout shift |
| Mobile | Heavy JS thread work, non-virtualized long lists, large images, animations on JS thread, excessive network |

## Payload: send only what consumers use
Each API response carries the fields its consumers read, not the whole model. For every route: list the fields returned, find every consumer (web, mobile, other services, MCP, webhooks, external clients), list the fields each one reads; the difference is waste (bytes, serialization, queries for relations nobody shows).
- Trim with the project's own mechanism: API Resource, serializer, DTO, `select` of columns, eager load only what is returned.
- Lists: paginate, and return the list fields, not the detail fields.
- Never remove a field another consumer reads. Public or versioned API: add (new version, `fields=` parameter, page-specific endpoint), never remove silently.
- Measure the same request before and after: payload size, query count, time.

## Front requests that should not happen
Count the requests of one page load and one typical action (network panel, a browser automation skill when available, or the dev server log). Then look in the code for:
- effects that fetch on every render (missing or unstable dependencies), and fetches repeated when the component remounts;
- the same endpoint called by several components without a shared cache (use the project's query cache: React Query / SWR / RTK Query / Apollo key, or lift the call);
- one request per list item (client-side N+1) instead of one list or batch request;
- data fetched for hidden UI (closed tabs, modals, below-the-fold) before it is shown;
- polling or refetch-on-focus more frequent than the data changes; search requests on every keystroke (no debounce, no cancel of the previous one);
- sequential `await`s of independent calls (`Promise.all`), and full list reloads after a mutation instead of a cache update;
- responses that could be cached (HTTP cache headers, ETag) or already exist in the store.

## Heavy pages
Measure first, with what the project has, then the standard tool (ask before downloading):
| Measure | Tool |
|---------|------|
| Page load (LCP, TBT, transferred bytes, requests, API calls, duplicates) | `bash scripts/page-scan.sh <url>` (Lighthouse summary; `--login <url>` once for pages behind a login), browser performance panel |
| Requests during user actions, console errors, interaction trace | Browser MCP (Playwright MCP, Chrome DevTools MCP) or browser skill when available |
| Bundle and chunks | build output sizes; Vite `rollup-plugin-visualizer`, Next.js `@next/bundle-analyzer`, webpack `webpack-bundle-analyzer`, any: `npx source-map-explorer <bundle.js>` |
| Expo / React Native bundle | Expo Atlas (`EXPO_ATLAS=1 npx expo start`), `npx expo export` sizes |

Measure a production build or staging: a dev server (Vite, webpack dev server, `next dev`) serves unbundled, unminified code, so its weight and timings mislead.

Usual causes: a large library imported whole (import the function, or a lighter lib already installed), no route-level code splitting, heavy components not lazy-loaded, images not resized/compressed/lazy (`loading="lazy"`, framework image component, modern formats), too many or too heavy fonts, polyfills and dev code in production, re-renders from wide contexts or unstable props, long lists not virtualized.

## Mobile apps (React Native, Expo, Android)
Measure with standard platform tools, on a **release build**, on a **real mid-range phone** when possible (emulators and debug builds are only indicative):
| Measure | Tool |
|---------|------|
| Cold start, janky frames, frame times, memory, CPU, installed size | `bash scripts/mobile-scan.sh <package> [--flow maestro.yaml]` (adb, `am start -W`, `dumpsys gfxinfo` / `meminfo` / `cpuinfo`) |
| The screen to optimize, logged in | a Maestro flow (`maestro test`), credentials through `-e` env vars |
| Performance score over a flow | Flashlight (`flashlight test --bundleId <pkg> --testCommand "maestro test flow.yaml"`) when installed |
| JS bundle | Expo Atlas (`EXPO_ATLAS=1 npx expo start`), `npx expo export` sizes, `react-native-bundle-visualizer` |
| iOS | Xcode Instruments (Time Profiler, Animation Hitches, Allocations) |
| Production users | EAS Observe / Sentry / Firebase Performance when the project has them |

Usual causes: long lists not virtualized (`FlatList`/`FlashList` with stable `keyExtractor`, `getItemLayout`), large images not resized or cached (`expo-image`), heavy work on the JS thread during navigation or scroll, animations on the JS thread (use Reanimated worklets / native driver), re-renders from wide contexts or inline props, requests fired on every focus or re-render, big responses parsed on the JS thread, too many startup imports (lazy-load screens and heavy modules), Hermes disabled.

## Backend code
Profile the slow route before changing it: Laravel Telescope / Debugbar / Clockwork / `DB::listen`, Symfony profiler, Django debug toolbar, Python `cProfile` / `py-spy`, Node `--cpu-prof`.
Look for: queries or HTTP calls inside loops, work repeated per item that can be done once, whole tables or files loaded in memory (use chunking, cursors, streaming), heavy synchronous work in the request (email, PDF, image, external API → queue/job), missing cache for stable read-heavy data, missing indexes (`EXPLAIN`), serialization of unused relations.

## Dead and duplicated code
Dead code and duplicates make pages heavier and the code slower to change.
| Stack | Unused code / exports / files | Duplication |
|-------|------------------------------|-------------|
| JS / TS | `npx knip` (files, exports, dependencies) | `npx jscpd <src>` |
| PHP | PHPStan with `tomasvotruba/unused-public`, `composer-unused` for packages | `npx jscpd <src>` (supports PHP) |
| Python | `vulture .`, `deptry .` for packages | `npx jscpd <src>` |

Tools report **candidates**. Before removing, check dynamic use: routes and controllers referenced by name, framework auto-discovery (providers, commands, listeners, Blade/Twig components), reflection, string-based imports, public API, used only by tests, config, CI. Duplicates: keep the version the project uses most and route the others through it, one group per commit, tests after each.

Command: `optimize` (`skills/optimize/SKILL.md`); result delivered as a visual report (`references/reports.md`).

## Measure with the tools the project already has
- SQL: query log / debugbar / Telescope / `EXPLAIN`, Django debug toolbar, ORM logging.
- HTTP: response time (`curl -w '%{time_total}'`), APM if present.
- Frontend: Lighthouse, browser performance panel, bundle analyzer, React Profiler.
- Mobile: React Native perf monitor, Flipper / dev tools, device testing (not only simulator).
- Memory/CPU: profilers of the runtime.

## Performance budgets
Pages and apps get heavy one small change at a time; a budget stops each step in the pull request that causes it.
- `.siska/perf-budget.json` (committed): limits per page (`pages`: `url`, `desktop`, `budget`) and per app (`apps`: `package`, `flow`, `budget`), and `tolerance_pct` (default 10). Syntax: `scripts/perf-budget.sh --help`.
- `.siska/perf/<name>.json` (committed): the baseline, the last accepted measure. A metric fails when it passes its budget, or gets worse than the baseline by more than the tolerance, even under the budget.
- `bash scripts/perf-budget.sh . run` measures every entry (`page-scan.sh` / `mobile-scan.sh`); `check <name> <metrics.json>` compares a measure made elsewhere (`--metrics` of both scan scripts).
- **First budget**: the current measure plus the tolerance, so it stops the growth today; after each accepted optimization, tighten it and record the new baseline (`--update-baseline`, recorded only when the measure passes). Targets to aim for: LCP ≤ 2500 ms, TBT ≤ 200 ms, CLS ≤ 0.1 (Core Web Vitals); on mobile, cold start ≤ 1500 ms, janky frames ≤ 5% on a mid-range phone.
- Budgets and baselines come from the same environment: a production build or staging for the web (never a dev server), a release build on the same device for mobile. Changing a budget or a baseline is a decision the user approves.
- In CI: build and start the app the way the project already does in its pipeline, then `perf-budget.sh . run` (`templates/ci/README.md`).

## Scalability (only when needed)
Database load, cache, queues, API rate, storage, concurrency, network, async processing. No premature optimization.
