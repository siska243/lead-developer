import type { AppServices } from "./services.js";

// Wire each function to the application's existing service (import it, or call
// the existing internal API). Generated per project during MCP integration; the
// template fails loudly instead of returning fake data.
export const services: AppServices = {
  orders: {
    async findForActor() {
      throw new Error("orders.findForActor is not bound to the application's order service");
    },
  },
};
