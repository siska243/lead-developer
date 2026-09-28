import { createMcpExpressApp } from "@modelcontextprotocol/sdk/server/express.js";
import { requireBearerAuth } from "@modelcontextprotocol/sdk/server/auth/middleware/bearerAuth.js";
import { getOAuthProtectedResourceMetadataUrl, mcpAuthMetadataRouter } from "@modelcontextprotocol/sdk/server/auth/router.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { OAuthMetadataSchema } from "@modelcontextprotocol/sdk/shared/auth.js";
import { jwtTokenVerifier } from "./auth.js";
import { services } from "./bindings.js";
import { loadHttpConfig } from "./config.js";
import { SCOPES } from "./scopes.js";
import { createMcpServer, type ActorResolver } from "./server.js";

const cfg = loadHttpConfig();

// The actor is the token subject; scopes are exactly those granted in the token.
const actorFromToken: ActorResolver = (authInfo) => {
  const sub = authInfo?.extra?.sub;
  return typeof sub === "string" ? { id: sub, scopes: authInfo!.scopes } : null;
};

const metadataResponse = await fetch(cfg.oauth.metadataUrl);
if (!metadataResponse.ok) throw new Error(`Cannot load authorization server metadata (${metadataResponse.status})`);
const oauthMetadata = OAuthMetadataSchema.parse(await metadataResponse.json());

// Host header validation (DNS rebinding) is automatic on localhost; set MCP_ALLOWED_HOSTS otherwise.
const app = createMcpExpressApp({ host: cfg.host, ...(cfg.allowedHosts.length ? { allowedHosts: cfg.allowedHosts } : {}) });

// Publishes /.well-known/oauth-protected-resource so clients discover the authorization server.
app.use(mcpAuthMetadataRouter({ oauthMetadata, resourceServerUrl: cfg.publicUrl, scopesSupported: Object.values(SCOPES) }));

const bearer = requireBearerAuth({
  verifier: jwtTokenVerifier(cfg.oauth),
  resourceMetadataUrl: getOAuthProtectedResourceMetadataUrl(cfg.publicUrl),
});

// Stateless Streamable HTTP: one server + transport per request, nothing shared between callers.
app.post(cfg.publicUrl.pathname, bearer, async (req, res) => {
  const server = createMcpServer(services, actorFromToken);
  const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
  res.on("close", () => {
    void transport.close();
    void server.close();
  });
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
});

// No server-initiated streams or sessions in stateless mode.
app.all(cfg.publicUrl.pathname, (_req, res) => {
  res.status(405).set("Allow", "POST").json({ jsonrpc: "2.0", error: { code: -32000, message: "Method not allowed." }, id: null });
});

app.listen(cfg.port, cfg.host, () => console.error(`MCP server listening on ${cfg.host}:${cfg.port}${cfg.publicUrl.pathname}`));
