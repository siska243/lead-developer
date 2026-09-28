---
name: audit-package
description: Dependency audit - vulnerabilities, abandoned or unmaintained packages, unused packages (composer, npm, pnpm, yarn, bun, pip).
argument-hint: "[--outdated] [path]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

Follow `${CLAUDE_SKILL_DIR}/../../references/dependencies.md`. Change nothing before the user approves.

1. **Vulnerabilities**: `bash ${CLAUDE_SKILL_DIR}/../../scripts/security-audit.sh <path or .> [--outdated]`.
2. **Maintenance** of every direct dependency (section "Maintenance status"): deprecated/abandoned, archived repo, last release date, replacement.
3. **Unused** packages (section "Unused dependencies"): run the tool, then verify each candidate before listing it.
4. **Report, short** – three tables:
   - `Vulnerable: Package | Installed | Severity | Advisory | Fixed in`
   - `At risk: Package | Last release | Status (deprecated/abandoned/archived/stale) | Replacement`
   - `Unused: Package | Evidence it is unused | Safe to remove (yes/check)`
   - `SKIP` / `no audit could run` = **not verified**: say so and what to install.
5. Ask which packages to remove or update. Then do it one group at a time with the project's package manager, and run tests + build after each group.
