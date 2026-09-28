// One scope per capability (least privilege). Keep in sync with the authorization server.
export const SCOPES = {
  ordersRead: "orders.read",
} as const;

export type Scope = (typeof SCOPES)[keyof typeof SCOPES];
