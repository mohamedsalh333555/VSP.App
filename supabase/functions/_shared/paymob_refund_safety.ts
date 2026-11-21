/** Refunding must not treat HTTP 2xx, gateway id, or prior-refund text as settlement proof. */
export function isConfirmedPaymobRefund(httpOk: boolean, response: unknown): boolean {
  if (!httpOk || response === null || typeof response !== "object" || Array.isArray(response)) return false;
  const v = response as Record<string, unknown>;
  // Reject contradictory/malformed provider flags. A successful response
  // explicitly labelled "not a refund" is not refund settlement proof.
  for (const field of ["success", "pending", "error_occured", "is_void", "is_voided", "is_refund"]) {
    if (field in v && typeof v[field] !== "boolean") return false;
  }
  if (v.success === false || v.pending === true || v.error_occured === true ||
    v.is_void === true || v.is_voided === true || v.is_refund === false) return false;
  return v.success === true || v.is_refund === true;
}
/** Unverified provider message means manual reconciliation, never automatic credit. */
export function isAlreadyRefundedProviderMessage(response: unknown): boolean {
  if (!response || typeof response !== "object" || Array.isArray(response)) return false;
  const v = response as Record<string, unknown>;
  const msg = [v.message, v.detail].filter((x) => typeof x === "string")
    .join(" ").toLowerCase();
  return msg.includes("already refunded") || msg.includes("already voided");
}
