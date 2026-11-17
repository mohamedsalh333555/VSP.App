import {
  computePaymobHMAC,
  verifyPaymobHmacSignature,
} from "../_shared/paymob_hmac.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

const obj = {
  amount_cents: 2500,
  created_at: "2026-11-17T10:00:00Z",
  currency: "EGP",
  error_occured: false,
  has_parent_transaction: false,
  id: 891,
  integration_id: 1234,
  is_3d_secure: true,
  is_auth: false,
  is_capture: false,
  is_refunded: false,
  is_standalone_payment: true,
  is_voided: false,
  order: { id: 447, merchant_order_id: "TEST_BOOKING" },
  owner: 19,
  pending: false,
  source_data: { pan: "4242", sub_type: "Visa", type: "card" },
  success: true,
};
const secret = "synthetic-ci-hmac-secret-not-a-real-credential";

async function independentHmac(message: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  return Array.from(new Uint8Array(await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(message),
  )), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.test("Paymob transaction HMAC matches independent SHA-512 20-field vector", async () => {
  // Independent explicit field vector; catches accidental reordering.
  const expectedMessage = [
    2500, "2026-11-17T10:00:00Z", "EGP", false, false, 891, 1234,
    true, false, false, false, true, false, 447, 19, false,
    "4242", "Visa", "card", true,
  ].join("");
  const actual = await computePaymobHMAC(obj, secret);
  assert(actual === await independentHmac(expectedMessage), "20-field HMAC order mismatch");
  assert(actual.length === 128, "SHA-512 hex digest must be exactly 128 characters");
  assert(verifyPaymobHmacSignature(actual, actual), "valid synthetic signature rejected");
  assert(verifyPaymobHmacSignature(actual.toUpperCase(), actual), "uppercase hex signature rejected");
});

Deno.test("Reject invalid, missing, malformed, and altered signatures", async () => {
  const expected = await computePaymobHMAC(obj, secret);
  const changedAmount = await computePaymobHMAC({ ...obj, amount_cents: 2501 }, secret);
  const changedOrder = await computePaymobHMAC({ ...obj, order: { id: 448 } }, secret);
  for (const signature of [
    "", "wrong", expected.slice(1), expected + "0",
    "z".repeat(128), "0".repeat(128), changedAmount, changedOrder,
  ]) {
    assert(!verifyPaymobHmacSignature(signature, expected), "invalid HMAC was accepted");
  }
});

Deno.test("No unauthenticated raw URL, HMAC proof or payload persisted by webhook", async () => {
  const source = await Deno.readTextFile(new URL("../paymob_webhook/index.ts", import.meta.url));
  const boundary = source.indexOf("const amountCents = Number(obj?.amount_cents)");
  assert(boundary > 0, "unable to identify the signed-payload boundary");
  const unauthenticated = source.slice(0, boundary);
  assert(unauthenticated.includes("verifyPaymobHmacSignature(receivedHmac, calculatedHmac)"),
    "the callback must verify the HMAC before processing payment state");
  assert(!/rawUrl|calculatedHmacPrefix|queryParams:|payload: payload,/.test(unauthenticated),
    "the rejection audit persists untrusted raw data");
  assert(!/^\s*receivedHmac,/m.test(unauthenticated),
    "the rejection audit persists the untrusted HMAC string");
  assert((unauthenticated.match(/rejected_before_authentication: true/g) || []).length >= 5,
    "one or more rejection paths lacks minimal audit metadata");
  assert(source.includes("obj.success === true && obj.pending === false"),
    "server must require explicit boolean payment-success indicators");
});

Deno.test("Paymob intention provider errors log status only, never response body", async () => {
  const source = await Deno.readTextFile(
    new URL("../create_paymob_intention/index.ts", import.meta.url),
  );
  assert(!/console\.(?:error|warn|log)\([\s\S]{0,180}\bintentionData\b/.test(source),
    "provider error response body might expose billing data or API tokens");
  assert(source.includes("httpStatus: intentionRes.status"),
    "provider error log must retain a non-sensitive HTTP status");
});


Deno.test("Refund and checkout error paths never echo provider or internal diagnostics", async () => {
  const webhook = await Deno.readTextFile(
    new URL("../paymob_webhook/index.ts", import.meta.url),
  );
  const checkout = await Deno.readTextFile(
    new URL("../create_paymob_intention/index.ts", import.meta.url),
  );
  assert(!/Paymob Refund API Response:\s*["'][^"']*["']\s*,\s*JSON\.stringify\(refundData\)/.test(webhook),
    "raw refund provider response must not be logged");
  assert(!/authErrText\s*=\s*await authRes\.text\(\)/.test(webhook),
    "provider authentication response body must not be copied into exceptions");
  assert(!/refundErrorMsg\s*=\s*refundData\.(?:message|detail)/.test(webhook),
    "refund ledger diagnostics must not persist raw third-party responses");
  assert(!/refundErrorMsg\s*=\s*refundEx(?:\?\.)?\.message/.test(webhook),
    "refund ledger diagnostics must not persist exception text");
  assert(!/JSON\.stringify\(\{\s*error:\s*err\?\.message\s*\|\|\s*String\(err\)/.test(checkout),
    "checkout must never return raw internal errors to Flutter");
  assert(checkout.includes('error: "Unable to create a payment session"'),
    "checkout failure must return a stable, sanitized message");
});
