import assert from "node:assert/strict";
import { test } from "node:test";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { createMcpServer } from "./server.js";
import type { Actor, AppServices, Order } from "./services.js";

const order: Order & { internalNote: string } = {
  id: "ord_1", status: "paid", total: 42, currency: "EUR", createdAt: "2026-01-01T00:00:00Z", internalNote: "secret",
};

const services: AppServices = {
  orders: { findForActor: async (actor, id) => (actor.id === "u1" && id === order.id ? order : null) },
};

async function connect(actor: Actor | null) {
  const server = createMcpServer(services, () => actor);
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const client = new Client({ name: "test", version: "1.0.0" });
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  return client;
}

const text = (result: Awaited<ReturnType<Client["callTool"]>>) => (result.content as { text: string }[])[0].text;

test("returns only mapped fields to an authorized actor", async () => {
  const client = await connect({ id: "u1", scopes: ["orders.read"] });
  const result = await client.callTool({ name: "get_order", arguments: { orderId: "ord_1" } });
  assert.equal(result.isError, undefined);
  assert.deepEqual(JSON.parse(text(result)), { id: "ord_1", status: "paid", total: 42, currency: "EUR", createdAt: "2026-01-01T00:00:00Z" });
});

test("denies an actor without the scope", async () => {
  const client = await connect({ id: "u1", scopes: [] });
  const result = await client.callTool({ name: "get_order", arguments: { orderId: "ord_1" } });
  assert.equal(result.isError, true);
  assert.match(text(result), /orders\.read/);
});

test("denies unauthenticated calls", async () => {
  const client = await connect(null);
  const result = await client.callTool({ name: "get_order", arguments: { orderId: "ord_1" } });
  assert.equal(result.isError, true);
});

test("hides orders not visible to the actor", async () => {
  const client = await connect({ id: "u2", scopes: ["orders.read"] });
  const result = await client.callTool({ name: "get_order", arguments: { orderId: "ord_1" } });
  assert.equal(result.isError, true);
  assert.equal(text(result), "Order not found.");
});

test("rejects invalid input", async () => {
  const client = await connect({ id: "u1", scopes: ["orders.read"] });
  const result = await client.callTool({ name: "get_order", arguments: { orderId: "../etc/passwd" } });
  assert.equal(result.isError, true);
});

test("returns a safe message when the service fails", async () => {
  const failing: AppServices = { orders: { findForActor: async () => { throw new Error("SQLSTATE[42S02] secret details"); } } };
  const server = createMcpServer(failing, () => ({ id: "u1", scopes: ["orders.read"] }));
  const [ct, st] = InMemoryTransport.createLinkedPair();
  const client = new Client({ name: "test", version: "1.0.0" });
  await Promise.all([server.connect(st), client.connect(ct)]);
  const result = await client.callTool({ name: "get_order", arguments: { orderId: "ord_1" } });
  assert.equal(result.isError, true);
  assert.doesNotMatch(text(result), /SQLSTATE/);
});
