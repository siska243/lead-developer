# Client configuration

Most MCP-compatible clients read a JSON file with an `mcpServers` object (file name and location depend on the client: e.g. `.mcp.json` at project root, or the client's settings). Check the client's documentation.

`mcp.json.example` shows both transports:
- **stdio** – the client starts the process locally; identity and scopes come from env. Keep scopes minimal.
- **http** – remote server; the client performs OAuth (discovered through `/.well-known/oauth-protected-resource`). No token in the file.

Never put secrets or tokens in a committed client config. Use env var references if the client supports them.
