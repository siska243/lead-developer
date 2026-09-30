---
name: check-code
description: Pre-commit check - tests, linters, hardcoded secrets and keys, tracked .env, debug leftovers; secret scan of the whole history (--history), performance budgets (--perf) and CI setup. Blocks the commit when anything fails.
argument-hint: "[--front] [--back] [--mobile] [--history] [--perf] [path]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

0. `--history` → run only `bash ${CLAUDE_SKILL_DIR}/../../scripts/secret-scan.sh <path or .> --history` and report each finding (commit, file:line, masked value): the value must be rotated even if deleted since; rewriting history is a separate high-risk step (impact, rollback, the team's agreement). Reviewed false positives go in `.siska/secrets-allow` with the reason.
0b. `--perf` → `bash ${CLAUDE_SKILL_DIR}/../../scripts/perf-budget.sh <path or .> run --report <tmp>/report.json` (the app must be running; for a dev server the figures are not comparable with a production baseline: say so). Over budget or regression → list each metric (now, budget, baseline) and the likely cause from the diff; never raise a budget to make it pass unless the user decides so.
1. Scope: `--front`, `--back`, `--mobile` (combinable) → `--scope front,back,…`; none → everything.
   Run `bash ${CLAUDE_SKILL_DIR}/../../scripts/check-project.sh <path or .> --run-tests --run-lint [--scope …]`.
2. Exit code 1 (`BLOCK` lines) → **commit refused**. List each problem (`file:line` when known) and fix it if it is in the scope of the current ticket; otherwise ask. Re-run until it passes.
3. `NOT verified` for a scope, or `no test or lint command detected` → say the code is **not verified**, and propose declaring the project's commands in `.siska/checks` (one per line).
4. The project has CI (`detect-stack.sh`: `ci:`) without these checks → propose adding the jobs of `${CLAUDE_SKILL_DIR}/../../templates/ci/` to its existing pipeline (`references/git.md`, section CI); add them only after the user says yes. First time on a project → also propose `secret-scan.sh . --history`.
5. Report, short: the scope checked, then `✅ ready to commit` or `❌ commit refused` + the problem list. Never commit while it fails. The automatic commit gate always checks every scope. When it fails or has warnings, also deliver the visual report (`${CLAUDE_SKILL_DIR}/../../references/reports.md`).
