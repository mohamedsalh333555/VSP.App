/** A successful PostgREST update is not proof that any row matched. */
export function isPersistedPaymobOrder(result: unknown, expectedOrderId: string): boolean {
  if (!result || typeof result !== "object" || !expectedOrderId.trim()) return false;
  const value = result as Record<string, unknown>;
  if (value.error != null || !value.data || typeof value.data !== "object") return false;
  const row = value.data as Record<string, unknown>;
  return row.id != null && row.paymob_order_id != null &&
    String(row.paymob_order_id) === expectedOrderId;
}
