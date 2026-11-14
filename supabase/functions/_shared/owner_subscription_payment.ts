// Shared by the authenticated status inquiry and the HMAC-verified webhook.
// This validates a provider response; it does not authorize a caller or move money.
type PaymentOrder = {
  paymob_order_id: unknown;
  gross_amount?: unknown;
  amount?: unknown;
};
type VerifiedPayment = { transactionId: string; amount: number };

function positiveInteger(value: unknown): number | null {
  if (
    typeof value !== "number" &&
    !(typeof value === "string" && /^[0-9]+$/.test(value))
  ) return null;
  const n = Number(value);
  return Number.isSafeInteger(n) && n > 0 && n <= 100_000_000_000 ? n : null;
}

function identifier(value: unknown): string | null {
  if (typeof value === "number") {
    return Number.isSafeInteger(value) && value > 0 ? String(value) : null;
  }
  return typeof value === "string" && /^[1-9][0-9]*$/.test(value)
    ? value
    : null;
}

// Compare exact minor units, avoiding float tolerances that accept a one-cent shortfall.
function moneyCents(value: unknown): number | null {
  if (typeof value !== "number" && typeof value !== "string") return null;
  const match = /^(\d+)(?:\.(\d+))?$/.exec(String(value));
  if (!match) return null;
  const fraction = match[2] || "";
  if (/[1-9]/.test(fraction.slice(2))) return null;
  return positiveInteger(
    Number(match[1]) * 100 + Number(fraction.slice(0, 2).padEnd(2, "0")),
  );
}

export function verifyOwnerSubscriptionPayment(
  tx: unknown,
  order: PaymentOrder,
): VerifiedPayment | null {
  if (!tx || typeof tx !== "object" || Array.isArray(tx)) return null;
  const v = tx as Record<string, unknown>;
  if (
    v.success !== true || v.pending !== false || v.currency !== "EGP" ||
    v.is_auth !== false || v.is_refunded !== false || v.is_voided !== false
  ) return null;
  // Optional flags differ between inquiry/callback API versions. Reject unknown types as well as true.
  for (
    const flag of [
      "is_refund",
      "is_void",
      "is_internal_refund",
      "error_occured",
    ]
  ) {
    if (v[flag] !== undefined && v[flag] !== false) return null;
  }
  if (
    v.refunded_amount_cents !== undefined && v.refunded_amount_cents !== 0 &&
    v.refunded_amount_cents !== "0"
  ) return null;
  const providerOrder = v.order && typeof v.order === "object"
    ? (v.order as Record<string, unknown>).id
    : v.order;
  const expectedOrderId = identifier(order.paymob_order_id);
  const transactionId = identifier(v.id);
  const paidCents = positiveInteger(v.amount_cents);
  const expectedCents = moneyCents(order.gross_amount ?? order.amount);
  if (
    !expectedOrderId || identifier(providerOrder) !== expectedOrderId ||
    !transactionId ||
    paidCents === null || expectedCents === null || paidCents !== expectedCents
  ) return null;
  return { transactionId, amount: paidCents / 100 };
}
