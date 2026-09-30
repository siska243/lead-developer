---
name: api-docs
description: Shareable API documentation like Postman - interactive page to read and send requests, Postman collection (Postman, Insomnia, Bruno), and the data structures of every endpoint (fields sent and returned with type, required, default, allowed values), from the project's OpenAPI.
argument-hint: "[--base-url <url>] [path]"
disable-model-invocation: true
---

Arguments: `$ARGUMENTS`

Apply the rules of `${CLAUDE_SKILL_DIR}/../../SKILL.md` and `${CLAUDE_SKILL_DIR}/../../references/documentation.md` (section API reference). Nothing is invented: every route, field, type and default comes from the code through the spec.

1. **Stack and environment**: `bash ${CLAUDE_SKILL_DIR}/../../scripts/detect-stack.sh <path or .>`, then find the OpenAPI file the project already has (`openapi.json|yaml`, `docs/`, `storage/`, a `/openapi.json` or `/docs` route, the generator's export command).
2. **No spec** → propose the generator of the stack (table in `references/documentation.md`), check the version is compatible with the installed framework, and install it only after the user says yes. It reads the real validation rules and resources (types, required, defaults, enums), which is what makes the structures true. Export the spec with its command (e.g. `php artisan scramble:export`, FastAPI `/openapi.json`).
3. **Check the spec**: routes in the spec vs the real route list (`php artisan route:list`, framework router); a route missing from the spec, or a 2xx response without schema, is reported (the front cannot know what it returns) and fixed in the generator's annotations or types when the user wants it.
4. **Generate**: `bash ${CLAUDE_SKILL_DIR}/../../scripts/api-docs.sh <spec> --out <docs folder>/api [--base-url <url of the environment>] --report <tmp>/report.json`:
   - `index.html`: interactive reference, **Test Request** and API client (the API must allow the page's origin, CORS);
   - `<name>.postman_collection.json`: for Postman, Insomnia or Bruno (import), `{{baseUrl}}` and `{{token}}` variables, one folder per tag; the token is set in the user's own environment, never in a file;
   - `api-structures.md`: per endpoint, parameters, request body and response fields with type, required, default, allowed values, format, example.
   Adapt to what the user works with: an existing Postman/Insomnia/Bruno collection in the repository → regenerate that one; a docs site → put the files where it serves them; `--base-url` of the environment they use (local, staging).
5. **Share**: publish `artifact.html` as a rich page when the agent can (read-only there: a shared page cannot call the API; say so), and give the paths of `index.html` and the collection. No secret, token or real personal data in any example.
6. **Report** (`${CLAUDE_SKILL_DIR}/../../references/reports.md`): endpoints, groups, secured, missing response schemas, missing descriptions, and the links.
