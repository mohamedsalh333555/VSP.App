/**
 * Reject malformed gateway refund inputs; never strip non-digits from a
 * provider transaction id. Otherwise "12test34" could wrongly refund 1234.
 *
 * All values originate from a server-claimed refund-queue row. This guard
 * is still necessary because historical data can be incomplete or corrupt.
 */
export function validatedPaymobRefundRequest(
  rawTransactionId: unknown,
  rawAmountEgp: unknown,
): { transactionId: string; transactionIdNumber: number; amountCents: number } | null {
  if (typeof rawTransactionId !== "string" && typeof rawTransactionId !== "number") return null;
  const transactionId = String(rawTransactionId).trim();
  if (!/^[1-9][0-9]*$/.test(transactionId)) return null;
  const transactionIdNumber = Number(transactionId);
  if (!Number.isSafeInteger(transactionIdNumber) || transactionIdNumber <= 0) return null;

  if (typeof rawAmountEgp !== "string" && typeof rawAmountEgp !== "number") return null;
  const money = typeof rawAmountEgp === "number"
    ? rawAmountEgp.toString()
    : rawAmountEgp.trim();
  // Reject scientific notation, fractional piasters, Infinity and NaN.
  if (!/^(?:0|[1-9][0-9]*)(?:\.[0-9]{1,2})?$/.test(money)) return null;
  const numberValue = Number(money);
  const amountCents = Math.round(numberValue * 100);
  if (!Number.isSafeInteger(amountCents) || amountCents <= 0) return null;
  return { transactionId, transactionIdNumber, amountCents };
}
