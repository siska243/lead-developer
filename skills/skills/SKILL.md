---
name: skills
description: List installed skills and MCP servers, find a missing one, vet it, and install it only with the user's consent.
argument-hint: "[list | find <need> | vet <source> | install <source>]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

Follow `${CLAUDE_SKILL_DIR}/../../references/orchestration.md`.

- `list` (default): `bash ${CLAUDE_SKILL_DIR}/../../scripts/list-capabilities.sh .` → one short table per kind (skills, MCP), duplicates merged.
- `find <need>`: say first if an installed skill/MCP already covers it; otherwise search the sources of `orchestration.md` §3 and show at most 5 candidates (source, installs, last update).
- `vet <source>`: fetch without running it, `bash ${CLAUDE_SKILL_DIR}/../../scripts/vet-skill.sh <dir>`, read `SKILL.md` and flagged files, give the verdict OK / caution / refuse with reasons.
- `install <source>`: vet first, show the verdict and the exact install command (`${CLAUDE_SKILL_DIR}/../../compat/`), then **ask**. Install only after an explicit yes, smallest scope. A no is final.
