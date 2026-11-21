import { claimDirectPaymobRefund, recordDirectPaymobRefundOutcome } from "../_shared/paymob_direct_refund_claim.ts";
function assert(value: unknown, msg: string): asserts value { if (!value) throw new Error(msg); }

Deno.test("Direct signed refund has one durable provider dispatch owner", async () => {
  const id = "789123";
  let inserted = false;
  let postCount = 0;
  const mock = { from: (table: string) => {
    assert(table === "paymob_refund_dispatch_claims", "unexpected table");
    const q: any = {
      insert: (data: any) => { postCount++; assert(data.paymob_transaction_id === id, "wrong ID"); return q; },
      select: () => q,
      maybeSingle: async () => {
        if (postCount === 1 && !inserted) { inserted = true; return { data: { paymob_transaction_id: id }, error: null }; }
        return { data: null, error: { code: "23505" } };
      },
    }; return q;
  } };
  const claim = { transactionId: id, orderReference: "TOURN_1V1_synthetic", context: "legacy_1v1" as const, amountCents: 2500 };
  assert(await claimDirectPaymobRefund(mock, claim), "first claim failed");
  assert(!await claimDirectPaymobRefund(mock, claim), "duplicate signed callback dispatched twice");
  assert(postCount === 2, "mock did not exercise unique conflict");
  for (const wrong of ["", "0", "12abc", "0012", "-12"]) {
    assert(!await claimDirectPaymobRefund(mock, { ...claim, transactionId: wrong }),
      "invalid transaction ID accepted");
  }
});

Deno.test("Direct refund claim fails closed when table not migrated", async () => {
  const db = { from: () => { const q:any = { insert: () => q, select: () => q,
    maybeSingle: async () => ({ data: null, error: { code: "42P01" } }) }; return q; } };
  assert(!await claimDirectPaymobRefund(db, {
    transactionId: "789", orderReference: "booking-test", context: "cancelled_booking", amountCents: 1500,
  }), "missing database table allowed money movement");
});

Deno.test("Only legacy 1v1 and cancelled bookings own direct refund dispatch", async () => {
  const src = await Deno.readTextFile(new URL("../paymob_webhook/index.ts", import.meta.url));
  assert((src.match(/claimDirectPaymobRefund\(supabase, \{/g)||[]).length === 2,
    "direct signed refund endpoint missing duplicate prevention");
  const one = src.slice(src.indexOf('if (specialReference.startsWith("TOURN_1V1_"))'),
    src.indexOf('if (specialReference.startsWith("TOURN_"))'));
  const cancelled = src.slice(src.indexOf('if (existingBooking.status === "cancelled")'),
    src.indexOf('const paidAmountEgp',src.indexOf('if (existingBooking.status === "cancelled")')));
  for (const [name,section] of [["legacy 1v1",one],["cancelled booking",cancelled]] as const) {
    const claim = section.indexOf("const directClaim = await claimDirectPaymobRefund(");
    const gate = section.indexOf("if (!directClaim)", claim);
    const refund = section.indexOf('const refundRes = await fetch("https://accept.paymob.com/api/acceptance/void_refund/refund"',gate);
    assert(claim >= 0 && gate > claim && refund > gate, name + " can refund before durable claim");
  }
  assert(!src.includes(".upsert({ paymob_transaction_id:"), "upsert could re-enable refund dispatch");
});
