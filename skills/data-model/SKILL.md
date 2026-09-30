---
name: data-model
description: Document the real data model - interactive explorer (zoom, pan, rotate, search, focus a table and its neighbours) plus docs page with ER diagram, read from the database schema; flags tables without primary key and foreign keys without index.
argument-hint: "[--only <table regex>] [path]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

Apply the rules of `${CLAUDE_SKILL_DIR}/../../SKILL.md` and `${CLAUDE_SKILL_DIR}/../../references/documentation.md`. Read-only: only the schema is read, never rows, and nothing is migrated.

1. **Stack**: `bash ${CLAUDE_SKILL_DIR}/../../scripts/detect-stack.sh <path or .>`. Pick the schema source the project already has:
   - Laravel 11+ → `bash ${CLAUDE_SKILL_DIR}/../../scripts/data-model.sh <path>` (the framework's own introspection, on the configured connection);
   - SQLite file → `--sqlite <file>`;
   - other stacks → export the schema with the project's own tool, then convert it to the normalized JSON (`data-model.sh --help`) and pass `--from-json`: Prisma (`prisma/schema.prisma`, or `prisma db pull`), Django (`python manage.py inspectdb` / model `_meta`), TypeORM or Sequelize entities, Doctrine (`bin/console doctrine:mapping:info` and the entities), Rails (`db/schema.rb`), raw SQL (`information_schema` with the project's client). Never guess a column or a relation.
2. **Environment**: check which database the configuration points to (host name only, never the credentials). A production database → ask before connecting, and prefer a local or staging copy.
3. **Generate** into the project's docs folder (none → `docs/`): `--markdown docs/data-model.md --json docs/data-model.json --html docs/data-model.html --artifact <tmp>/explorer.html --report <tmp>/report.json`.
   - `data-model.html` is the **interactive explorer**, the main view for large schemas: zoom, pan, rotate, search a table or a column, click a table for its columns, indexes and relations, focus on its neighbours (1 or 2 levels, or only them), several layouts, deep link `#table`. FK without index are dashed.
   - The Markdown keeps the static diagram and the full dictionary; more than 60 tables → one static diagram per domain with `--only` (`'^(orders|order_)'`).
4. **Share**: publish `<tmp>/explorer.html` as a rich page when the agent can (private by default; it contains the schema, no rows), and give the path of `docs/data-model.html` to open locally.
5. **Report** (`${CLAUDE_SKILL_DIR}/../../references/reports.md`): the visual report with the ER diagram and the checks (tables without primary key, foreign keys without index). Fixing them is a separate ticket with a migration, never done here.
