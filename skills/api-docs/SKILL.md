---
name: api-docs
description: API documentation like API Platform, in the project's colours - interactive reference to read and send requests, served by the app or shared, with exports (Postman collection and environment, OpenAPI for Insomnia, Bruno, Hoppscotch) and the data structures of every endpoint (fields sent and returned with type, required, default, allowed values).
argument-hint: "[--base-url <url>] [--brand-color <css colour>] [path]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

Apply the rules of `${CLAUDE_SKILL_DIR}/../../SKILL.md` and `${CLAUDE_SKILL_DIR}/../../references/documentation.md` (section API reference). Nothing is invented: every route, field, type and default comes from the code through the spec.

1. **Stack and environment**: `bash ${CLAUDE_SKILL_DIR}/../../scripts/detect-stack.sh <path or .>`, then find the OpenAPI file the project already has (`openapi.json|yaml`, `docs/`, `storage/`, a `/openapi.json` or `/docs` route, the generator's export command).
2. **No spec** → propose the generator of the stack (table in `references/documentation.md`), check the version is compatible with the installed framework, and install it only after the user says yes. It reads the real validation rules and resources (types, required, defaults, enums), which is what makes the structures true. Export the spec with its command (e.g. `php artisan scramble:export`, FastAPI `/openapi.json`).
3. **Check the spec**: routes in the spec vs the real route list (`php artisan route:list`, framework router); a route missing from the spec, or a 2xx response without schema, is reported (the front cannot know what it returns) and fixed in the generator's annotations or types when the user wants it.
4. **Look like the product**: pass `--project <front-end dir>` so the page takes the project's own brand colour (CSS variable `--primary` / `--color-primary` / `--brand`, `tailwind.config` `primary`, `theme-color` meta) and say where it came from; `--brand-color` when the design system names it elsewhere (`references/design-system.md`); `--logo <local file>` with the product's logo from the repository; `--font` with the product's font family. Never invent a colour or a logo: nothing found → neutral, and say so.
5. **Generate**: `bash ${CLAUDE_SKILL_DIR}/../../scripts/api-docs.sh <spec> --out <docs folder>/api [--base-url <url of the environment>] --project <front dir> --report <tmp>/report.json`:
   - `index.html`: interactive reference, **Test Request** and API client (the API must allow the page's origin, CORS), exports in the bar (Postman collection, Postman environment, OpenAPI);
   - `<name>.postman_environment.json` and `openapi.json` next to it;
   - `<name>.postman_collection.json`: for Postman, Insomnia or Bruno (import), `{{baseUrl}}` and `{{token}}` variables, one folder per tag; the token is set in the user's own environment, never in a file;
   - `api-structures.md`: per endpoint, parameters, request body and response fields with type, required, default, allowed values, format, example.
   Adapt to what the user works with: an existing Postman/Insomnia/Bruno collection in the repository → regenerate that one; a docs site → put the files where it serves them; `--base-url` of the environment they use (local, staging).
6. **Serve it from the app, like API Platform** (only if the user wants it): copy the files to the app's public docs path (`public/docs/api/` for Laravel, Symfony, Vite, Next.js) and pass `--spec-url` with the URL where the generator serves the live spec (Scramble `/docs/api.json`, FastAPI `/openapi.json`), so the page is always in sync. Internal API docs are not for the public internet: keep them behind the app's auth, or limited to non-production environments (Scramble's default gate); ask which.
7. **Share** (with the agent's rich page when it has one; Claude Code: `compat/claude-code.md`, exports as real files there): publish `artifact.html` as a rich page when the agent can (read-only there: a shared page cannot call the API; say so), and give the paths of `index.html` and the collection. No secret, token or real personal data in any example.
8. **Report** (`${CLAUDE_SKILL_DIR}/../../references/reports.md`): endpoints, groups, secured, missing response schemas, missing descriptions, and the links.
