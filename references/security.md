# Security

Security is priority #1. Secure before exposing.

## Checklist per change
| Area | Verify |
|------|--------|
| Authentication | Every new route/endpoint/screen/tool is behind the right auth guard. Session and token lifetimes. |
| Authorization | Policies/gates/middlewares per action and per resource (ownership, tenant). Test each role. No check only on the frontend. |
| Validation | All external input validated server-side (form requests, DTOs, schemas). Whitelist fields (no mass assignment of `role`, `is_admin`…). |
| SQL injection | Query builder / ORM bindings only. No string concatenation in raw queries. |
| XSS | Escape output by default. Sanitize any rendered HTML. No `dangerouslySetInnerHTML` / `{!! !!}` / `v-html` on user data. |
| CSRF | Enabled for cookie sessions; state-changing actions not on GET. |
| SSRF | Validate/allow-list outgoing URLs built from user input; block internal IP ranges and metadata endpoints. |
| Uploads | Validate type (content, not only extension), size, store outside web root or on private storage, random names, no execution. |
| Sessions & cookies | `HttpOnly`, `Secure`, `SameSite`; regenerate on login; invalidate on logout. |
| CORS | Explicit origins, no `*` with credentials. |
| Rate limiting | Login, password reset, OTP, public APIs, expensive endpoints. |
| Secrets & tokens | Env vars / secret manager only, never in code, logs, URLs, client bundles or commits. `.env` in `.gitignore`. |
| Logs | No passwords, tokens, card data, personal data beyond need. |
| Errors | Generic messages in production; no stack trace, SQL, paths. Debug mode off in production. |
| Dependencies | See `dependencies.md`. |
| Config & infra | Least privilege IAM, private buckets by default, TLS, security headers, no open admin ports. |

## Tools
- `bash scripts/security-audit.sh <project>` – dependency audit for the detected stack (read-only).
- Use a security-review skill/tool when available for a second pass on sensitive diffs (auth, payments, uploads, permissions, MCP).

## High-risk areas – extra care
Auth, authorization, payments, file handling, webhooks (verify signatures), OAuth (see `mcp.md`), admin features, data export, multi-tenancy.
