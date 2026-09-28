function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable ${name}`);
  return value;
}

const list = (value: string | undefined) => (value ?? "").split(",").map((s) => s.trim()).filter(Boolean);

export function loadHttpConfig() {
  return {
    host: process.env.MCP_HOST ?? "127.0.0.1",
    port: Number(process.env.MCP_PORT ?? 3001),
    publicUrl: new URL(required("MCP_PUBLIC_URL")),
    allowedHosts: list(process.env.MCP_ALLOWED_HOSTS),
    oauth: {
      issuer: required("OAUTH_ISSUER"),
      audience: required("OAUTH_AUDIENCE"),
      jwksUrl: required("OAUTH_JWKS_URL"),
      metadataUrl: required("OAUTH_METADATA_URL"),
    },
  };
}

export function loadStdioActor() {
  const id = process.env.MCP_STDIO_ACTOR_ID;
  return id ? { id, scopes: list(process.env.MCP_STDIO_SCOPES) } : null;
}
