---
name: document
description: Document the application professionally - functional documentation of features, API documentation (OpenAPI), code documentation - human-sounding, verified against the code.
argument-hint: "[--functional | --api | --code] [feature, module or path]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

Follow `${CLAUDE_SKILL_DIR}/../../references/documentation.md` and the rules of `${CLAUDE_SKILL_DIR}/../../SKILL.md` (never invent).

- No option: the feature page (functional then technical) for the given feature; nothing given → list the features found and ask which one.
- `--functional`: only the functional part.
- `--api`: API blocks and the OpenAPI file for the given endpoints (all if none given).
- `--code`: code documentation (PHPDoc/JSDoc/TSDoc/docstrings) for the given path.

Before writing: find the existing docs and their format. After: check every endpoint, field and status against the code, then report in two lines which files were written and what is marked "to confirm".
