/** A successful PostgREST update is not proof that any row matched. */
export function isPersistedPaymobOrder(result: unknown, expectedOrderId: string): boolean {
  if (!result || typeof result !== "object" || !expectedOrderId.trim()) return false;
  const value = result as Record<string, unknown>;
  if (value.error != null || !value.data || typeof value.data !== "object") return false;
  const row = value.data as Record<string, unknown>;
  return row.id != null && row.paymob_order_id != null &&
    String(row.paymob_order_id) === expectedOrderId;
}

/**
 * A signed callback still needs exact server-side order correlation. An
 * absent stored ID is never a match: the checkout handler must bind it first.
 */
export function matchesBoundPaymobOrder(stored: unknown, signed: unknown): boolean {
  const normalized = (value: unknown): string | null => {
    if (typeof value === "number") {
      return Number.isSafeInteger(value) && value > 0 ? String(value) : null;
    }
    return typeof value === "string" && /^[1-9][0-9]*$/.test(value)
      ? value : null;
  };
  const expected = normalized(stored);
  return expected !== null && expected === normalized(signed);
}
