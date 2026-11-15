import '../../../../data/models.dart';

/// Compares the quote on the booking screen with a fresh, bookable venue row.
/// The booking RPC remains the final price authority after this preflight.
class BookingPriceSnapshotGuard {
  const BookingPriceSnapshotGuard._();

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
        (serverQuote - displayedTotal).abs() <= 0.01 &&
        (latest.depositAmount - displayed.depositAmount).abs() <= 0.01 &&
        latest.needsDeposit == displayed.needsDeposit;
  }
}
