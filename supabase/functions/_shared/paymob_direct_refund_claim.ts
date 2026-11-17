/**
 * At-most-once automatic dispatch for *direct* signed Paymob refunds.
 *
 * This does not grant refund authority: callers must already have verified
 * HMAC, server integration, currency, amount, order binding and transaction
 * lifecycle. The DB table is INSERT/SELECT/UPDATE by service_role ONLY.
 * Any missing table / duplicate / transient DB error fails closed.
 */
export type DirectRefundContext = "legacy_1v1" | "cancelled_booking";
type Claim = {
  transactionId: string;
  orderReference: string;
  context: DirectRefundContext;
  amountCents: number;
};

export async function claimDirectPaymobRefund(db: any, claim: Claim): Promise<boolean> {
  const id = String(claim?.transactionId ?? "").trim();
  if (!/^[1-9][0-9]*$/.test(id) || !Number.isSafeInteger(Number(id)) ||
    typeof claim?.orderReference !== "string" ||
    claim.orderReference.length < 1 || claim.orderReference.length > 256 ||
    !["legacy_1v1", "cancelled_booking"].includes(claim.context) ||
    !Number.isSafeInteger(claim.amountCents) || claim.amountCents <= 0) return false;
  try {
    // No upsert: ON CONFLICT must never re-enable an external money movement.
    const { data, error } = await db.from("paymob_refund_dispatch_claims")
      .insert({
        paymob_transaction_id: id,
        order_reference: claim.orderReference,
        refund_context: claim.context,
        amount_cents: claim.amountCents,
      })
      .select("paymob_transaction_id")
      .maybeSingle();
    return error == null && data?.paymob_transaction_id === id;
  } catch {
    return false;
  }
}

export async function recordDirectPaymobRefundOutcome(
  db: any, transactionId: string, gatewayAcknowledged: boolean,
): Promise<boolean> {
  try {
    const { data, error } = await db.from("paymob_refund_dispatch_claims")
      .update({
        status: gatewayAcknowledged ? "gateway_acknowledged" : "requires_reconciliation",
        updated_at: new Date().toISOString(),
      })
      .eq("paymob_transaction_id", transactionId)
      .eq("status", "claimed")
      .select("paymob_transaction_id")
      .maybeSingle();
    return error == null && data?.paymob_transaction_id === transactionId;
  } catch {
    return false;
  }
}
