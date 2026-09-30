# Requests




## T25 · Update the plugin (commit, push, installed version)
- Status: 🔄 in progress · Priority: P1 · Created: 2026-09-30 · Updated: 2026-09-30
- Instructions: 2026-09-30 nothing applied to Rubix; update the plugin. What did I forget to make the plugin more efficient and interesting?
  - 2026-09-30: ok to skip the commit gate for this update (old 1.8.1 hook); do suggestions 1 (CI) and 2 (history secret scan).

## T26 · Checks in CI (tests, lint, secret scan on every PR)
- Status: ✅ done · Priority: P1 · Created: 2026-09-30 · Updated: 2026-09-30
- Instructions: 2026-09-30 suggestion 1: run the checks in CI, since local hooks can be bypassed.
- Result: .github/workflows/checks.yml (plugin) + templates/ci GitHub Actions and GitLab CI; actions pinned by verified commit SHA; not run on GitHub yet (first run on the PR)

## T27 · Secret scan of the whole git history
- Status: ✅ done · Priority: P1 · Created: 2026-09-30 · Updated: 2026-09-30
- Instructions: 2026-09-30 suggestion 2: scan the whole git history for secrets committed in the past.
- Result: secret-scan.sh --history / --range, masked output with commit and file:line, .siska/secrets-allow; check-code --history; 9 tests
