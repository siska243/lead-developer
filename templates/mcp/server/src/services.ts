// Contract between the MCP layer and the application's EXISTING services.
// The MCP layer never reimplements business logic, queries or permissions:
// bind these functions to the services the application already uses (bindings.ts).

export interface Actor {
  id: string;
  scopes: string[];
}

export interface Order {
  id: string;
  status: string;
  total: number;
  currency: string;
  createdAt: string;
}

export interface AppServices {
  orders: {
    // Must apply the application's own authorization (ownership, tenant) for `actor`.
    // Returns null when the order does not exist or is not visible to the actor.
    findForActor(actor: Actor, orderId: string): Promise<Order | null>;
  };
}
