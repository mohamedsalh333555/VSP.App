/** Keep a minimal, auditable subset of HMAC-verified Paymob fields. */
export function sanitizePaymobAuditPayload(input: unknown): Record<string, unknown> {
  if (!input || typeof input !== "object" || Array.isArray(input)) return {};
  const v = input as Record<string, unknown>;
  const audit: Record<string, unknown> = {};
  for (const k of ["id","created_at","amount_cents","currency","integration_id",
    "success","pending","is_refunded","is_refund","is_voided","is_void",
    "is_auth","is_capture","error_occured","refunded_amount_cents",
    "has_parent_transaction"]) {
    if (["string", "boolean", "number"].includes(typeof v[k])) audit[k] = v[k];
  }
  if (v.order && typeof v.order === "object" && !Array.isArray(v.order)) {
    const id = (v.order as Record<string, unknown>).id;
    if (typeof id === "number" || typeof id === "string") audit.order = { id };
  } else if (typeof v.order === "number" || typeof v.order === "string") audit.order = v.order;
  if (v.source_data && typeof v.source_data === "object" && !Array.isArray(v.source_data)) {
    const src = v.source_data as Record<string, unknown>;
    const method: Record<string, string> = {};
    for (const k of ["type", "sub_type"]) {
      if (typeof src[k] === "string") method[k] = String(src[k]).slice(0,64);
    }
    if (Object.keys(method).length) audit.source_data = method;
  }
  return audit;
}
