/**
 * Server-side allow-list for Paymob transaction callback integration IDs.
 * Never use IDs supplied by Flutter/browser clients for authorization.
 *
 * Historical IDs for outstanding payment orders may be configured explicitly
 * through server-only PAYMOB_WEBHOOK_ALLOWED_INTEGRATION_IDS (comma-separated).
 * Do not log configuration values or use a client-provided allow-list.
 */
function positiveIntegrationId(value: unknown): string | null {
  if (typeof value !== "string" && typeof value !== "number") return null;
  const str = String(value).trim();
  if (!/^[1-9][0-9]*$/.test(str)) return null;
  const n = Number(str);
  return Number.isSafeInteger(n) && n > 0 ? String(n) : null;
}

export function isAuthorizedPaymobIntegration(
  receivedId: unknown,
  cardIntegrationId: unknown,
  walletIntegrationId: unknown,
  historicIntegrationIds: string = "",
): boolean {
  const received = positiveIntegrationId(receivedId);
  if (!received) return false;
  const configured = [cardIntegrationId, walletIntegrationId].map(positiveIntegrationId);
  // Required current production settings must both exist, or fail closed.
  if (configured.some((id) => !id)) return false;
  for (const historic of historicIntegrationIds.split(",")) {
    const parsed = positiveIntegrationId(historic);
    if (parsed !== null) configured.push(parsed);
  }
  return configured.includes(received);
}
