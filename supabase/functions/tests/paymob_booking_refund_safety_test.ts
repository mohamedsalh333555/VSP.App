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

Deno.test("Booking refund must persist a compare-and-set gateway dispatch marker", async () => {
  const src = await Deno.readTextFile(new URL("../process_paymob_refund/index.ts", import.meta.url));
  const read = src.indexOf('.select("id, status, metadata")');
  const existing = src.indexOf("if (refundClaimMetadata.gateway_refund_dispatched_at)",read);
  const marker = src.indexOf("gateway_refund_dispatched_at: dispatchedAt",existing);
  const cas = src.indexOf('.is("metadata->>gateway_refund_dispatched_at", null)',marker);
  const denied = src.indexOf('if (dispatchClaimError || !dispatchClaim)',cas);
  const call = src.indexOf('const rr = await fetch("https://accept.paymob.com/api/acceptance/void_refund/refund"',denied);
  assert(read > 0 && existing > read && marker > existing && cas > marker && denied > cas && call > denied,
    "refund must be claimed durably and checked before gateway call");
  assert(src.includes('refund_lease_expires_at: "9999-12-31T00:00:00Z"'),
    "SQL lease expiry could permit duplicate gateway dispatch");
  const postDispatch = src.slice(marker,src.indexOf("const refundTxnId",marker));
  assert((postDispatch.match(/\.\.\.dispatchedMetadata/g)||[]).length >= 2,
    "ambiguous gateway responses must retain the dispatch marker");
  assert(!src.includes('String(claim.paymob_transaction_id || "").replace(/\\D/g, "")'),
    "invalid refund ID could be silently converted into a different transaction");
});
