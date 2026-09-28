import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { SCOPES, type Scope } from "./scopes.js";
import type { Actor, AppServices } from "./services.js";

// Resolves who is calling. HTTP: from the validated OAuth token. stdio: from env.
export type ActorResolver = (authInfo: { clientId: string; scopes: string[]; extra?: Record<string, unknown> } | undefined) => Actor | null;

const deny = (message: string): CallToolResult => ({ isError: true, content: [{ type: "text", text: message }] });

// Every tool starts with this check; the application's own policies still apply in the service.
function requireScope(actor: Actor | null, scope: Scope): { actor: Actor } | { error: CallToolResult } {
  if (!actor) return { error: deny("Not authenticated.") };
  if (!actor.scopes.includes(scope)) return { error: deny(`Missing required scope: ${scope}.`) };
  return { actor };
}

export function createMcpServer(services: AppServices, resolveActor: ActorResolver): McpServer {
  const server = new McpServer({ name: "app-mcp", version: "1.0.0" });

  server.registerTool(
    "get_order",
    {
      title: "Get order",
      description: "Return one order visible to the caller (status, total, currency, creation date). Requires scope orders.read.",
      inputSchema: { orderId: z.string().min(1).max(64).regex(/^[A-Za-z0-9_-]+$/) },
      annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false },
    },
    async ({ orderId }, extra) => {
      const access = requireScope(resolveActor(extra.authInfo), SCOPES.ordersRead);
      if ("error" in access) return access.error;
      const { actor } = access;
      try {
        const order = await services.orders.findForActor(actor, orderId);
        if (!order) return deny("Order not found.");
        // Explicit field mapping: never forward the whole domain object.
        const { id, status, total, currency, createdAt } = order;
        return { content: [{ type: "text", text: JSON.stringify({ id, status, total, currency, createdAt }) }] };
      } catch (error) {
        // Details stay in server logs; the client gets a safe message.
        console.error("get_order failed", error);
        return deny("The order could not be retrieved. Try again later.");
      }
    },
  );

  return server;
}
