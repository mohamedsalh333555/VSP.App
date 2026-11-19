/**
 * Paymob transaction POST callback: 20 signed fields in Paymob's documented order.
 * Do not reuse for card-token or subscription callbacks (different HMAC contracts).
 * No secrets or webhook payloads are logged here.
 */
export async function computePaymobHMAC(obj: any, hmacSecret: string): Promise<string> {
  const signedValues = [
    obj.amount_cents,
    obj.created_at,
    obj.currency,
    obj.error_occured,
    obj.has_parent_transaction,
    obj.id,
    obj.integration_id,
    obj.is_3d_secure,
    obj.is_auth,
    obj.is_capture,
    obj.is_refunded,
    obj.is_standalone_payment,
    obj.is_voided,
    obj.order?.id ?? obj.order,
    obj.owner,
    obj.pending,
    obj.source_data?.pan ?? "",
    obj.source_data?.sub_type ?? "",
    obj.source_data?.type ?? "",
    obj.success,
  ].join("");

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(hmacSecret),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, encoder.encode(signedValues)),
  );
  return Array.from(signature, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

/**
 * Fixed 128-character comparison for two SHA-512 hex signatures.
 * Always performs the same 128 comparison iterations, including malformed lengths;
 * it does not accept missing, truncated, non-hex, or modified signatures.
 * This is for WebCrypto runtimes without a timingSafeEqual primitive.
 */
export function verifyPaymobHmacSignature(
  receivedHmac: string,
  calculatedHmac: string,
): boolean {
  const received = receivedHmac.toLowerCase();
  const calculated = calculatedHmac.toLowerCase();
  let difference = received.length ^ calculated.length;
  for (let index = 0; index < 128; index++) {
    difference |= (received.charCodeAt(index) || 0) ^
      (calculated.charCodeAt(index) || 0);
  }
  return difference === 0 &&
    /^[0-9a-f]{128}$/.test(received) &&
    /^[0-9a-f]{128}$/.test(calculated);
}
