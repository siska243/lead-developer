# OAuth for a remote MCP server

The MCP server is an **OAuth 2.1 resource server**. It never issues tokens itself: an authorization server (the app's existing OAuth provider – Laravel Passport, Symfony/League OAuth2 server, Keycloak, Auth0, Cognito, Entra ID, … – or a new one) does.

## Authorization server requirements
| Requirement | Why |
|-------------|-----|
| Authorization Code flow + PKCE (`S256`) | Public clients (desktop/CLI agents) cannot keep secrets |
| `state` validated by clients, exact redirect URI matching | CSRF and code interception |
| RFC 8414 metadata (`/.well-known/oauth-authorization-server`) or OIDC discovery | Clients discover endpoints |
| Audience / resource indicator (RFC 8707) = `MCP_PUBLIC_URL` | A token for another API is rejected here |
| Scopes = `src/scopes.ts` values | Least privilege per tool |
| Short-lived access tokens (≈5–15 min), refresh token rotation | Limit stolen token impact |
| Revocation endpoint (RFC 7009) | Kill compromised grants |
| Dynamic client registration (RFC 7591) **only if** you accept unknown clients | Otherwise pre-register clients |
| JWT access tokens with JWKS, or introspection (RFC 7662) | Token validation (`src/auth.ts` handles JWT) |

## Environments
Separate per environment (dev / staging / production): authorization server tenant or realm, client IDs, secrets, redirect URIs, signing keys, `MCP_PUBLIC_URL`. Never reuse production credentials elsewhere.

## Secrets
- Env vars or secret manager only (`server/.env.example` lists names).
- Never in git, logs, URLs, error messages or client bundles.
- Tokens stored by clients in the OS keychain / encrypted storage – not in plain config files.

## Checklist
- [ ] Token signature, `iss`, `aud`, `exp` validated (`src/auth.ts`)
- [ ] Scope checked in every tool (`requireScope`)
- [ ] 401 responses carry `resource_metadata` (done by `requireBearerAuth`)
- [ ] Refresh rotation and revocation tested
- [ ] Per-environment config verified
