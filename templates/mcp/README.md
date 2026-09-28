# MCP templates

Starting point for MCP integration (`references/mcp.md`) when the project is Node/TypeScript or needs a standalone MCP process.
For Laravel, Symfony or Python, use the framework's official SDK (see `references/mcp.md`) and apply the same structure.

```text
server/   TypeScript MCP server (@modelcontextprotocol/sdk 1.x): stdio + stateless Streamable HTTP,
          OAuth resource server, scope-checked tool, tests
oauth/    Authorization server requirements and per-environment setup
client/   Client configuration examples
```

## Architecture
```text
MCP client → transport (stdio | HTTP + Bearer) → tool (validate, scope) → AppServices (bindings.ts)
          → existing application service → business logic → repository → database
```

## Use
1. Copy `server/` into the project (e.g. `mcp/`), keep the project's package manager.
2. Verify the SDK version installed matches the code (`npm view @modelcontextprotocol/sdk version`, changelog).
3. Replace the example `orders` contract in `services.ts` / `bindings.ts` / `scopes.ts` with the capabilities the user approved, bound to the **existing** services.
4. One tool = one capability = one scope. Keep the `requireScope` check and explicit output mapping.
5. `npm test` – adapt the tests in `src/server.test.ts` to each tool (authorized, missing scope, unauthenticated, not visible, invalid input, service failure).
6. Configure env from `.env.example` (never commit values), then OAuth (`oauth/README.md`) for HTTP.
7. Rate limiting and TLS: provided by the existing reverse proxy / API gateway, or the app's existing limiter. Verify before exposing.

## Verified behavior (template as shipped)
- 6 tool tests pass (`npm test`).
- HTTP: `401` + `WWW-Authenticate … resource_metadata=…` without/with invalid token, `/.well-known/oauth-protected-resource/<path>` served, `405` on GET, `403` on unexpected Host header (localhost binding).
