# Documentation

**Every new or changed feature is documented in the same ticket: functional first, then technical.** A feature without its documentation is not done.

## Rules
- **Nothing invented**: every route, field, rule, role, screen and message comes from the code. Not verifiable → write "to confirm" and ask.
- **Reuse what exists**: the project's docs folder, format and tools (docs site, OpenAPI file, Swagger UI, wiki). Never a second documentation system.
- **Human writing**: plain, specific, short sentences; the reader's vocabulary; no filler, no promotional or AI-sounding wording. Apply a humanizer skill/tool when available.
- **Same language** as the existing docs; none yet → the developer's language (`language` setting, else the language of their messages). Visual reports set `"lang"` to it so their labels follow.
- Changed feature → update its page; removed feature → remove or mark its page.

## Feature page
Location: the project's docs folder; none → `docs/features/<feature>.md`.

```markdown
# <Feature name>

## Functional
- **Purpose**: what problem it solves, in one or two sentences.
- **Who**: roles / user types who can use it (and who cannot).
- **How it works**: the user journey, step by step, from the user's point of view.
- **Business rules**: limits, calculations, statuses, validations, as the user experiences them.
- **Screens / entry points**: where it appears (screen, menu, email, notification).
- **Errors and edge cases**: what the user sees when something goes wrong, and what to do.

## Technical
- **API calls**: one block per endpoint (see below).
- **Data**: tables/models read or written, important columns, migrations.
- **Background work**: jobs, queues, events, listeners, scheduled tasks, notifications.
- **Dependencies & config**: services, packages, env var names (never values), feature flags.
- **Security**: authentication, permissions/policies, rate limits.
- **Tests**: where the tests of this feature live.
```

API block:
```markdown
### `POST /api/orders` – create an order
- Auth: Bearer token (Sanctum) · Permission: `orders.create`
- Body: `items[]` (required, 1–50), `items[].product_id` (int), `items[].quantity` (int ≥ 1), `note` (string ≤ 500, optional)
- 201: `{ "id": 42, "status": "pending", "total": 1990 }`
- 422: validation errors per field · 403: missing permission · 429: rate limit
- Example: `curl -X POST … -H "Authorization: Bearer <token>" -d '{"items":[{"product_id":7,"quantity":2}]}'`
```

## API reference (OpenAPI)
If the project has an OpenAPI file or generator, update it with every API change. Otherwise propose one (separate ticket) with the framework's tool – verify the version is compatible first:

| Stack | Tool |
|-------|------|
| FastAPI | built-in (`/openapi.json`) |
| Laravel | `dedoc/scramble` (types, defaults and enums inferred from FormRequests and API Resources) or `knuckleswtf/scribe` |
| Symfony | API Platform, or `nelmio/api-doc-bundle` |
| NestJS | `@nestjs/swagger` (DTO decorators) |
| Express / Fastify / other Node | `@asteasolutions/zod-to-openapi` when the project validates with Zod, Fastify's `@fastify/swagger`, otherwise `swagger-jsdoc` |
| Django REST framework | `drf-spectacular` |
| Spring Boot | `springdoc-openapi` |
| Go | `swaggo/swag` |

Then `api-docs` turns the spec into an interactive page with a request client, a Postman collection and the data structures of every endpoint (`scripts/api-docs.sh`); `data-model` documents the database schema (`scripts/data-model.sh`).

Validate the spec when possible: `npx @redocly/cli lint <openapi file>` (ask before downloading it).

## Project documentation
The README (or the project's docs entry point) lets a new developer, without asking anyone: understand what the project does, install it, configure it (env var **names** and where to get the values, never values), run it, test it, deploy it. Any ticket that changes one of these updates the README in the same ticket.

## Code documentation (mandatory for new and changed code)
- Format of the project: PHPDoc, JSDoc/TSDoc, Python docstrings, shell header comments.
- Every new or changed class, module, public function or method, endpoint, job, command and script gets a doc comment: purpose, parameters, return value, errors thrown, side effects (DB writes, events, external calls).
- Non-obvious code gets a comment that explains **why** (business rule, workaround of an external bug, performance or security choice). Never a comment that repeats the code.
- Types (TypeScript, PHP types, Python type hints) are part of the documentation: use them where the project does.

## Check before delivery
- Every new or changed class, public function, endpoint and script has its doc comment; README still true.
- Every endpoint, field and status in the page exists in the code.
- Examples are runnable (same field names, same status codes).
- Links resolve; OpenAPI lint passes when available.
