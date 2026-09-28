# MCP integration (`/siska-lead-developer:mcp`)

Goal: expose existing application capabilities to MCP-compatible clients **by reusing existing business logic**, with least privilege and no arbitrary system access.

```text
MCP tool → Application service → Business logic → Repository → Database
```
An MCP tool is a thin adapter, like a controller: validate input, check scope, call the existing service, map the result. No business logic, no SQL in the tool.

## The 17 steps
1. **Analyze the project** – `workflow.md` steps 1–3.
2. **Detect the stack** – `bash scripts/detect-stack.sh <project>` (reports existing MCP SDKs too).
3. **Detect existing MCP integration** – search `@modelcontextprotocol/sdk`, `mcp` (Python), `laravel/mcp`, `mcp/sdk`, `symfony/mcp-bundle`, `.mcp.json`, `mcp.json`, `/mcp` routes. Extend it rather than creating a second one.
4. **Analyze authentication** – current guards (session, Sanctum/Passport, JWT, OAuth provider, API keys), who the MCP caller will act as.
5. **Analyze permissions** – roles, policies, gates, scopes already defined. MCP scopes map onto them; they never bypass them.
6. **Propose an architecture** – transport (stdio for local tools, Streamable HTTP for remote), where it lives (inside the app vs separate process), auth mode, tool list with scopes. Present it to the user.
7. **Ask for missing information** – which capabilities to expose, target clients, hosting, authorization server (existing OAuth provider or new), environments, rate limits. Never guess.
8. **Generate files** – prefer the framework's official SDK:

   | Stack | SDK (verify installed/compatible version) |
   |-------|------|
   | Laravel | `laravel/mcp` |
   | Symfony | `symfony/mcp-bundle` (on `mcp/sdk`) |
   | Other PHP | `mcp/sdk` |
   | Node / TypeScript | `@modelcontextprotocol/sdk` – template in `templates/mcp/server/` |
   | Python / FastAPI | `mcp` official Python SDK |

   Read the SDK docs for the installed version before writing code (APIs change between majors).
9. **Configure authentication** – stdio: runs as the local user, credentials from env. HTTP: Bearer tokens validated on every request (signature, expiry, audience/resource, issuer).
10. **Configure OAuth when needed** – see below and `templates/mcp/oauth/`.
11. **Create MCP tools** – see tool rules below.
12. **Define permissions** – one scope per capability, least privilege.
13. **Test** – unit tests per tool (valid input, invalid input, missing scope, forbidden resource, service error); an end-to-end call through an MCP client/inspector.
14. **Audit** – `bash scripts/security-audit.sh`, dependency audit of the SDK.
15. **Document** – tools, scopes, env vars, client configuration (`templates/mcp/client/`).
16. **Verify security** – checklist below + `security.md`.
17. **Verify regressions** – the app's existing routes, auth and tests still pass; MCP routes do not alter existing middleware stacks.

## Tool rules
- Specialized, predictable, documented, validated: `orders.list_recent`, `invoices.get`, `reports.monthly_revenue`.
- Input schema strict: types, bounds, enums, max lengths, formats (regex) – see `templates/mcp/server/src/server.ts`.
- Output: only fields the client needs; no secrets, no internal IDs that are not needed, paginated.
- Annotate read-only vs destructive tools; destructive tools require explicit write scopes and should be confirmable by the client.
- **Forbidden**: `execute_anything`, `run_sql`, `run_shell`, `execute_command`, generic proxies, file system access outside a defined scope, eval.
- Tool errors return safe messages (no stack trace, SQL, path).

## Scopes (least privilege)
```text
users.read   users.write   orders.read   orders.create   payments.read   reports.read
```
Each tool declares the single scope it needs. Scopes are checked in the tool **and** the underlying policies still apply (ownership, tenant).

## OAuth (remote HTTP servers)
- Authorization Code flow + **PKCE**; `state` checked; exact redirect URI matching.
- The MCP server is a **resource server**: publish OAuth Protected Resource Metadata (`/.well-known/oauth-protected-resource`) pointing to the authorization server; return `401` with `WWW-Authenticate` including `resource_metadata`.
- Validate tokens: signature/introspection, `exp`, issuer, audience/resource bound to this server (RFC 8707), scopes.
- Short-lived access tokens, refresh with rotation, revocation supported.
- Tokens stored securely (never in logs, URLs or client bundles).
- Separate clients, secrets and redirect URIs for dev / staging / production.
- **Never hardcode** client secrets or signing keys – env vars / secret manager.

## Security checklist
- [ ] No arbitrary execution tool
- [ ] Every tool validated + scope-checked + policy-checked
- [ ] HTTP: TLS, auth on every request, rate limiting, Origin/Host validation (DNS rebinding) for local HTTP servers
- [ ] Secrets only in env; `.env.example` documents names only
- [ ] Logs without tokens or personal data
- [ ] Existing app behavior unchanged
