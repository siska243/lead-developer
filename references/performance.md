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

## Measure with the tools the project already has
- SQL: query log / debugbar / Telescope / `EXPLAIN`, Django debug toolbar, ORM logging.
- HTTP: response time (`curl -w '%{time_total}'`), APM if present.
- Frontend: Lighthouse, browser performance panel, bundle analyzer, React Profiler.
- Mobile: React Native perf monitor, Flipper / dev tools, device testing (not only simulator).
- Memory/CPU: profilers of the runtime.

## Scalability (only when needed)
Database load, cache, queues, API rate, storage, concurrency, network, async processing. No premature optimization.
