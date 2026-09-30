---
name: check-code
description: Pre-commit check - tests, linters, hardcoded secrets and keys, tracked .env, debug leftovers. Blocks the commit when anything fails.
argument-hint: "[--front] [--back] [--mobile] [path]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

1. Scope: `--front`, `--back`, `--mobile` (combinable) → `--scope front,back,…`; none → everything.
   Run `bash ${CLAUDE_SKILL_DIR}/../../scripts/check-project.sh <path or .> --run-tests --run-lint [--scope …]`.
2. Exit code 1 (`BLOCK` lines) → **commit refused**. List each problem (`file:line` when known) and fix it if it is in the scope of the current ticket; otherwise ask. Re-run until it passes.
3. `NOT verified` for a scope, or `no test or lint command detected` → say the code is **not verified**, and propose declaring the project's commands in `.siska/checks` (one per line).
4. Report, short: the scope checked, then `✅ ready to commit` or `❌ commit refused` + the problem list. Never commit while it fails. The automatic commit gate always checks every scope. When it fails or has warnings, also deliver the visual report (`${CLAUDE_SKILL_DIR}/../../references/reports.md`).
