# Requests





## T28 · Performance budgets (stop pages and apps from getting heavier)
- Status: ✅ done · Priority: P1 · Created: 2026-09-30 · Updated: 2026-09-30
- Instructions: 2026-09-30 do suggestion 3: performance budgets – keep each page's measures and alert when weight or LCP grows.
- Result: scripts/perf-budget.sh (run/check, budget + baseline drift, --update-baseline, report), --metrics on page-scan and mobile-scan, check-code --perf, optimize locks the gain, CI step; 13 tests; checked on the real Rubix metrics; v1.11.0
