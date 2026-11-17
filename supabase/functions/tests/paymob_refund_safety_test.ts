import { isConfirmedPaymobRefund, isAlreadyRefundedProviderMessage } from "../_shared/paymob_refund_safety.ts";
import { markTournamentRefundDispatched, REFUND_DISPATCH_HOLD_UNTIL } from "../_shared/paymob_tournament_dispatch.ts";
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

Deno.test("Persisted queue dispatch CAS verifies current lease before external refund", async () => {
  const id = "9c4f86c2-8ea4-480a-aa92-3bec10b0412b";
  const locked_until = "2026-11-17T15:00:00Z";
  const trace: Array<[string, unknown]> = [];
  const mock = { from: (table: string) => {
    trace.push(["table",table]); const q: any = {
      update: (data: unknown) => { trace.push(["update",data]); return q; },
      eq: (field: string, value: unknown) => { trace.push([field,value]); return q; },
      select: (cols: string) => { trace.push(["select",cols]); return q; },
      maybeSingle: async () => ({ data: { id }, error: null }),
    }; return q;
  } };
  assert(await markTournamentRefundDispatched(mock, "cancellation_refund_queue", { id, locked_until }),
    "a correctly claimed refund must be markable");
  assert(trace.some(([k,v]) => k === "locked_until" && v === locked_until),
    "mark must compare the original 15-minute lease");
  assert(trace.some(([k,v]) => k === "update" && typeof v === "object" &&
    v !== null && (v as Record<string,unknown>).locked_until === REFUND_DISPATCH_HOLD_UNTIL),
    "mark must keep the lease beyond automatic recovery");
  assert(!await markTournamentRefundDispatched(mock, "cancellation_refund_queue",
    { id, locked_until: null }), "missing claim lease accepted");
  assert(!await markTournamentRefundDispatched(mock, "untrusted_table" as any,
    { id, locked_until }), "unexpected table accepted");
  const noRows = { from: () => { const q: any = {
    update: () => q, eq: () => q, select: () => q,
    maybeSingle: async () => ({ data: null, error: null }),
  }; return q; } };
  assert(!await markTournamentRefundDispatched(noRows, "team_league_cancellation_refund_queue",
    { id, locked_until }), "zero-row CAS treated as successful dispatch");
});

Deno.test("All three tournament queue refund POSTs require durable dispatch claim", async () => {
  const src = await Deno.readTextFile(new URL("../process_tournament_refund/index.ts",import.meta.url));
  assert((src.match(/markTournamentRefundDispatched\(adminClient,/g)||[]).length===3,
    "a refund queue lacks durable dispatch");
  assert((src.match(/if \(!dispatchAllowed\) \{/g)||[]).length===3,
    "failed dispatch guard could still call Paymob");
});
