/** Ensure a push is never sent to a token belonging to another account.
 * The caller is also required to query device tokens with .eq('user_id', id).
 * This helper provides a second source-level guard and stable de-duplication.
 */
export function selectOwnedFcmTokens(
  rows: unknown, recipientId: string,
): string[] {
  if (!recipientId || !Array.isArray(rows)) return [];
  const tokens = new Set<string>();
  for (const row of rows) {
    if (!row || typeof row !== "object" || Array.isArray(row)) continue;
    const item = row as Record<string, unknown>;
    if (item.user_id !== recipientId || typeof item.token !== "string") continue;
    const token = item.token.trim();
    if (token.length > 0) tokens.add(token);
  }
  return [...tokens];
}
