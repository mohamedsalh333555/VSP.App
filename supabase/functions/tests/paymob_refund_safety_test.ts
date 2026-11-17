import { isConfirmedPaymobRefund, isAlreadyRefundedProviderMessage } from "../_shared/paymob_refund_safety.ts";
function assert(condition: unknown, message: string): asserts condition { if (!condition) throw new Error(message); }
Deno.test("Explicit Paymob refund result required, not ID or text", () => {
  assert(isConfirmedPaymobRefund(true, { success: true }), "positive response rejected");
  assert(isConfirmedPaymobRefund(true, { is_refund: true }), "positive refund flag rejected");
  for (const [status,payload] of [
    [false,{success:true}], [true,{id:123}], [true,{success:false,id:123}],
    [true,{success:false,is_refund:true}], [true,{success:true,pending:true}],
    [true,{success:true,error_occured:true}], [true,{success:true,is_voided:true}],
    [true,null], [true,"success"], [true,[]],
  ] as const) assert(!isConfirmedPaymobRefund(status,payload),"unverified refund accepted");
  assert(isAlreadyRefundedProviderMessage({message:"Transaction already refunded"}), "previous refund not recognized");
  assert(!isConfirmedPaymobRefund(true,{message:"already refunded"}),"provider text treated as proof");
});
Deno.test("All three refund queues require reconciliation rather than post-dispatch retry", async () => {
  const src = await Deno.readTextFile(new URL("../process_tournament_refund/index.ts",import.meta.url));
  assert((src.match(/let refundRequestSent = false;/g)||[]).length===3,"not all queues have dispatch tracking");
  assert((src.match(/refundRequestSent = true;/g)||[]).length===3,"not all queues track dispatch");
  assert((src.match(/if \(item\.retry_count >= 3 \|\| isAmbiguousTimeout \|\| refundRequestSent\)/g)||[]).length===3,
    "one refund queue may retry an already-dispatched request");
  assert(!src.includes('refundData.is_refund === true || refundData.id'),"id alone treated as refund success");
  assert(!src.includes('refundId = "ALREADY_REFUNDED_AT_GATEWAY"'),"provider text treated as refund proof");
  assert(!src.includes('Paymob authentication failed: " + JSON.stringify(authData)'),"auth response leak");
  assert(!src.includes('String(authErr?.message || authErr)'),"auth error leak");
});
