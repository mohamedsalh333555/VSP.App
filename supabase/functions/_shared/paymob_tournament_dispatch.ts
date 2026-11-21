/**
 * Persist a refund dispatch before the external Paymob POST. Current SQL
 * claim-next leases expire after 15 minutes; a process crash after dispatch
 * would otherwise allow duplicate requests. Hold the lease for manual
 * reconciliation if the worker never records a definitive result.
 */
export const REFUND_DISPATCH_HOLD_UNTIL = "9999-12-31T00:00:00Z";
const TABLES = [
  "cancellation_refund_queue",
  "vsp_1v1_cancellation_refund_queue",
  "team_league_cancellation_refund_queue",
] as const;
export type RefundQueueTable = typeof TABLES[number];
export async function markTournamentRefundDispatched(
  adminClient: any, table: RefundQueueTable,
  claim: { id: unknown; locked_until: unknown },
): Promise<boolean> {
  if (!TABLES.includes(table) || !claim ||
    typeof claim.id !== "string" || !/^[0-9a-fA-F-]{36}$/.test(claim.id) ||
    typeof claim.locked_until !== "string" ||
    !Number.isFinite(Date.parse(claim.locked_until))) return false;
  try {
    // Optimistic CAS: only the worker holding this exact claim lease may mark.
    const { data, error } = await adminClient.from(table)
      .update({
        failure_reason: "GATEWAY_DISPATCHED_RECONCILE_BEFORE_RETRY",
        locked_until: REFUND_DISPATCH_HOLD_UNTIL,
        updated_at: new Date().toISOString(),
      })
      .eq("id", claim.id)
      .eq("status", "processing")
      .eq("locked_until", claim.locked_until)
      .select("id")
      .maybeSingle();
    return error == null && data?.id === claim.id;
  } catch {
    return false;
  }
}
