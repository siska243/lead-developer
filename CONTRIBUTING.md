# Contributing

## Principles
The skill applies its own rules to itself: exact scope, minimum change, nothing invented, zero regression.

- `SKILL.md` stays short (identity, rules, workflow, reference map). Details go to `references/`.
- The core stays vendor-neutral ("AI coding agent", "MCP-compatible client"). Agent-specific content goes to `compat/<agent>.md` only.
- Every command, API or package named in a reference must exist; verify against official docs or the real tool.
- Scripts: bash, `set -u`, read-only on analyzed projects, `--help`, no silent overwrite, shared helpers in `scripts/lib.sh`, shellcheck-clean.

## Before a PR
```bash
bash tests/scripts.test.sh
npx shellcheck -x -P scripts scripts/*.sh tests/*.sh
cd templates/mcp/server && npm install && npm test
```
Update `CHANGELOG.md`. One branch per change (`feature/…`, `fix/…`, `docs/…`), conventional commits describing the technical change.
