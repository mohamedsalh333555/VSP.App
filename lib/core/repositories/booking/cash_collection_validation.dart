/// Client-side guard for the owner cash-confirmation path.
///
/// The backend RPC remains authoritative for authorization, amounts,
/// reconciliation, and idempotency. Rejecting a malformed local amount avoids
/// presenting a false successful receipt or re-collecting an online deposit.
class CashCollectionValidation {
  const CashCollectionValidation._();

  static double? calculateDue({
    required double totalPrice,
    required double depositPaid,
    required String paymentMethod,
    required String paymentStatus,
  }) {
    if (paymentMethod.toLowerCase().trim() != 'cash') return null;
    if (const {
      'paid',
      'fully_paid',
      'refunded',
      'refund_pending',
      'refund_failed',
    }.contains(paymentStatus.toLowerCase().trim())) {
      return null;
    }
    if (!totalPrice.isFinite ||
        !depositPaid.isFinite ||
        totalPrice <= 0 ||
        depositPaid < 0 ||
        depositPaid > totalPrice) {
      return null;
    }
    final remaining = totalPrice - depositPaid;
    if (!remaining.isFinite || remaining < 0) return null;
    // The authoritative RPC can reconcile a fully covered deposit without
    // collecting or notifying another cash payment (already_confirmed=true).
    if (remaining == 0) return 0.0;
    return remaining;
  }
}
