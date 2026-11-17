import { isConfirmedPaymobRefund } from "../_shared/paymob_refund_safety.ts";

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

// Test only synthetic provider outputs; no credentials or external payments.
Deno.test("Booking refund cannot succeed from a Paymob transaction ID alone", () => {
  assert(isConfirmedPaymobRefund(true, { success: true, id: 78 }), "explicit refund success rejected");
  assert(isConfirmedPaymobRefund(true, { is_refund: true, id: 78 }), "explicit refund flag rejected");
  for (const result of [
    { id: 78 }, { transaction_id: 78 }, { success: false, id: 78 },
    { success: true, pending: true }, { success: true, is_void: true },
    { success: false, is_refund: true }, { error_occured: true, is_refund: true },
    "already refunded", {},
  ]) assert(!isConfirmedPaymobRefund(true, result), "unverified payment refund was accepted");
  assert(!isConfirmedPaymobRefund(false, { success: true }), "HTTP error accepted");
});

Deno.test("Booking refund processor never stores raw Paymob error bodies", async () => {
  const s = await Deno.readTextFile(new URL("../process_paymob_refund/index.ts", import.meta.url));
  assert(s.includes("isConfirmedPaymobRefund(refundHttpOk, refundResponse)"),
    "refund source must use explicit provider proof");
  assert(!s.includes("Boolean(refundResponse.id)"), "provider response ID-only proof reintroduced");
  assert(!s.includes("gateway_error_detail: errorText"), "raw Paymob auth response stored");
  assert(!s.includes("refund_response: refundResponse"), "raw Paymob refund response stored");
  assert(!s.includes("gateway_error: gatewayError?.message"), "raw Paymob exception stored");
  const providerGate = s.indexOf("const refundSuccess = isConfirmedPaymobRefund(");
  const ledger = s.indexOf('admin.rpc("record_booking_gateway_refund_atomic"', providerGate);
  const notification = s.indexOf('admin.from("notifications").insert(', ledger);
  assert(providerGate > 0 && ledger > providerGate && notification > ledger,
    "refund success message must follow verified refund and DB ledger recording");
});
