# Documentation

**Every new or changed feature is documented in the same ticket: functional first, then technical.** A feature without its documentation is not done.

## Rules
- **Nothing invented**: every route, field, rule, role, screen and message comes from the code. Not verifiable → write "to confirm" and ask.
- **Reuse what exists**: the project's docs folder, format and tools (docs site, OpenAPI file, Swagger UI, wiki). Never a second documentation system.
- **Human writing**: plain, specific, short sentences; the reader's vocabulary; no filler, no promotional or AI-sounding wording. Apply a humanizer skill/tool when available.
- **Same language** as the existing docs (otherwise the user's language).
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
| Laravel | `dedoc/scramble` or `knuckleswtf/scribe` |
| Symfony | API Platform, or `nelmio/api-doc-bundle` |
| NestJS | `@nestjs/swagger` |
| Express / other Node | `swagger-jsdoc` |

Validate the spec when possible: `npx @redocly/cli lint <openapi file>` (ask before downloading it).

## Code documentation
- Format of the project: PHPDoc, JSDoc/TSDoc, Python docstrings.
- Document public APIs of modules, non-obvious behavior, business rules, side effects, thrown errors. Not what the code already says.
- Comments explain **why**.

## Check before delivery
- Every endpoint, field and status in the page exists in the code.
- Examples are runnable (same field names, same status codes).
- Links resolve; OpenAPI lint passes when available.
