import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { services } from "./bindings.js";
import { loadStdioActor } from "./config.js";
import { createMcpServer } from "./server.js";

// Local transport: the process acts as one configured actor with an explicit scope list.
const actor = loadStdioActor();
const server = createMcpServer(services, () => actor);
await server.connect(new StdioServerTransport());
// stdout carries the protocol: log only to stderr.
console.error("MCP server running on stdio");
