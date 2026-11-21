/**
 * A Paymob refund is not considered reconciled until the associated DB write
 * returns a successful, nonempty row set. PostgREST UPDATE without `select`
 * reports success even when zero rows matched its predicates.
 *
 * Keep the queue's durable dispatch hold until the final settlement write.
 */
export async function confirmedRefundLedgerWrite(query: any): Promise<boolean> {
  try {
    const { data, error } = await query.select("id");
    return error == null && Array.isArray(data) && data.length === 1 &&
      data[0] && data[0].id != null;
  } catch {
    return false;
  }
}
