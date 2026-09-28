---
name: audit-package
description: Vulnerability audit of the project's dependencies (composer, npm, pnpm, yarn, bun, pip).
argument-hint: "[--outdated] [path]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

1. Run `bash ${CLAUDE_SKILL_DIR}/../../scripts/security-audit.sh <path or .> [--outdated]` with the given arguments.
2. Report, short:
   - one table: `Package | Installed | Severity | Advisory | Fixed in | Direct/transitive`
   - lines `SKIP` / `RESULT: no audit could run` = **not verified**, say so and say what to install.
3. Propose fixes following `${CLAUDE_SKILL_DIR}/../../references/dependencies.md` (smallest fixing version, breaking changes, one package at a time). **Update nothing** without the user's approval; after an approved update, run the tests.
