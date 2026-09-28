import { InvalidTokenError } from "@modelcontextprotocol/sdk/server/auth/errors.js";
import type { OAuthTokenVerifier } from "@modelcontextprotocol/sdk/server/auth/provider.js";
import { createRemoteJWKSet, jwtVerify } from "jose";

// Validates JWT access tokens issued by the authorization server: signature (JWKS),
// issuer, audience (this MCP server) and expiry. Scopes come from the `scope` claim.
// If the authorization server issues opaque tokens, replace with RFC 7662 introspection.
export function jwtTokenVerifier(cfg: { issuer: string; audience: string; jwksUrl: string }): OAuthTokenVerifier {
  const jwks = createRemoteJWKSet(new URL(cfg.jwksUrl));
  return {
    async verifyAccessToken(token) {
      try {
        const { payload } = await jwtVerify(token, jwks, { issuer: cfg.issuer, audience: cfg.audience });
        return {
          token,
          clientId: String(payload.client_id ?? payload.azp ?? ""),
          scopes: typeof payload.scope === "string" ? payload.scope.split(" ").filter(Boolean) : [],
          expiresAt: payload.exp,
          extra: { sub: payload.sub },
        };
      } catch {
        throw new InvalidTokenError("Invalid or expired access token");
      }
    },
  };
}
