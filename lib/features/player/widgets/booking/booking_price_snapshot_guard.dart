import '../../../../data/models.dart';

/// Compares the quote on the booking screen with a fresh, bookable venue row.
/// The booking RPC remains the final price authority after this preflight.
class BookingPriceSnapshotGuard {
  const BookingPriceSnapshotGuard._();

  /// Fail closed before offering an online deposit if the venue's configured
  /// deposit is invalid or larger than the actual selected booking price.
  /// This is client preflight only: the booking RPC remains authoritative.
  static bool isValidDepositQuote({
    required double bookingTotal,
    required double deposit,
    required bool needsDeposit,
  }) {
    if (!bookingTotal.isFinite || bookingTotal <= 0 ||
        !deposit.isFinite || deposit < 0) {
      return false;
    }
    if (!needsDeposit) return true;
    // Floating-point reconstruction of slot totals may vary at a tiny scale.
    return deposit > 0 && deposit <= bookingTotal + 0.000001;
  }

  static bool matches({
    required Stadium displayed,
    required Stadium latest,
    required int halfHourSlots,
    required bool rentBall,
    required double displayedTotal,
  }) {
    if (displayed.id != latest.id || !latest.isVerified || latest.isBlocked ||
        halfHourSlots <= 0 || !latest.pricePerHour.isFinite ||
        latest.pricePerHour <= 0 || !latest.ballPrice.isFinite ||
        latest.ballPrice < 0 || !latest.depositAmount.isFinite ||
        !displayedTotal.isFinite) {
      return false;
    }
    final serverQuote = latest.pricePerHour * halfHourSlots / 2 +
        (rentBall ? latest.ballPrice : 0);
    return serverQuote.isFinite &&
        isValidDepositQuote(
          bookingTotal: serverQuote,
          deposit: latest.depositAmount,
          needsDeposit: latest.needsDeposit,
        ) &&
        (serverQuote - displayedTotal).abs() <= 0.01 &&
        (latest.depositAmount - displayed.depositAmount).abs() <= 0.01 &&
        latest.needsDeposit == displayed.needsDeposit;
  }
}
