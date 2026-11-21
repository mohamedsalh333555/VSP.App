/**
 * Classify an HMAC-authenticated Paymob transaction callback.
 *
 * This is intentionally independent of payment amounts, order IDs and
 * database state: the webhook must validate those separately. Never use the
 * provider's 'success' flag alone to credit a transaction.
 */
export type PaymobWebhookOutcome = "paid" | "pending" | "failed" | "reversed" | "unresolved";

export function classifyPaymobWebhookOutcome(tx: unknown): PaymobWebhookOutcome {
  if (!tx || typeof tx !== "object" || Array.isArray(tx)) return "unresolved";
  const v = tx as Record<string, unknown>;

  // An in-flight event cannot close a booking, even when success=false.
  if (v.pending === true) return "pending";
  if (v.pending !== false) return "unresolved";

  // A signed refund/void is not fresh revenue. Actual refunds require the
  // booking's separate authoritative accounting RPC before notification.
  if (
    v.is_refunded === true || v.is_voided === true ||
    v.is_refund === true || v.is_void === true ||
    v.is_internal_refund === true ||
    (v.refunded_amount_cents !== undefined &&
      v.refunded_amount_cents !== null &&
      v.refunded_amount_cents !== 0 &&
      v.refunded_amount_cents !== "0")
  ) return "reversed";

  // An authorization-only transaction is not necessarily captured; avoid
  // confirming an inconsistent success/error flag combination.
  if (v.success === true) {
    return v.is_auth === true || v.error_occured === true ? "unresolved" : "paid";
  }
  return v.success === false ? "failed" : "unresolved";
}
