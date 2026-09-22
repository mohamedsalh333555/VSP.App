import '../../../data/models.dart';

/// Pure domain rule engine for booking business logic.
/// Contains zero Supabase dependencies — all methods are stateless and testable.
///
/// Covers:
/// - Manual booking payment normalization (deposit vs full payment detection)
/// - Pending booking expiry rules (5-minute payment window)
/// - Challenge expiry rules (4-hour creation timeout or 12-hour proximity)
/// - Match result submission time-lock guard
class BookingDomainRules {
  const BookingDomainRules._();

  // ═══════════════════════ Payment Normalization ═══════════════════════════

  /// Normalizes manual booking payment status fields based on business rules.
  ///
  /// Rules:
  /// - depositPaid >= totalPrice → status='paid', isPaid=true, isDepositPaid=true
  /// - depositPaid > 0 → status='deposit_paid', isDepositPaid=true
  /// - Otherwise: unchanged
  ///
  /// Returns a record with the normalized (isPaid, isDepositPaid, paymentStatus).
  static ({bool isPaid, bool isDepositPaid, String paymentStatus})
      normalizeManualBookingPayment({
    required double depositPaid,
    required double totalPrice,
    required bool currentIsPaid,
    required bool currentIsDepositPaid,
    required String currentPaymentStatus,
  }) {
    if (totalPrice <= 0) {
      // No price to compare against — keep existing values
      return (
        isPaid: currentIsPaid,
        isDepositPaid: currentIsDepositPaid,
        paymentStatus: currentPaymentStatus,
      );
    }

    if (depositPaid >= totalPrice) {
      return (isPaid: true, isDepositPaid: true, paymentStatus: 'paid');
    } else if (depositPaid > 0) {
      return (
        isPaid: currentIsPaid,
        isDepositPaid: true,
        paymentStatus: 'deposit_paid',
      );
    }

    return (
      isPaid: currentIsPaid,
      isDepositPaid: currentIsDepositPaid,
      paymentStatus: currentPaymentStatus,
    );
  }

  // ═══════════════════════ Pending Booking Expiry ══════════════════════════

  /// Returns true if a pending booking has exceeded the 8-minute payment window.
  /// Expired pending bookings should not block time slots in availability checks.
  static bool isPendingBookingExpired(DateTime createdAt, DateTime now) {
    return now.difference(createdAt.toLocal()).inMinutes >= 8;
  }

  // ═══════════════════════ Challenge Expiry ════════════════════════════════

  /// Returns true if a pending challenge booking should be auto-expired.
  ///
  /// Expiry conditions (either triggers expiry):
  /// - The challenge was created more than 4 hours ago without opponent response
  /// - The match start time is within 12 hours and opponent has not responded
  static bool shouldChallengeExpire({
    required DateTime createdAt,
    required DateTime startTime,
    required DateTime now,
  }) {
    if (now.difference(createdAt).inHours >= 4) return true;
    if (startTime.difference(now).inHours <= 12) return true;
    return false;
  }

  // ═══════════════════════ Result Submission Time-Lock ════════════════════

  /// Returns true if result submission is time-locked (match has not ended yet).
  /// Prevents pre-match result fraud by enforcing submission only after [matchEndTime].
  static bool isResultSubmissionTimeLocked(DateTime matchEndTime, DateTime now) {
    return now.toUtc().isBefore(matchEndTime.toUtc());
  }

  // ═══════════════════════ Booking Visibility Filter ══════════════════════

  /// Returns true if a booking should be included in availability/display results.
  ///
  /// Filters out:
  /// - Cancelled bookings
  /// - Expired pending bookings (pending > 8 minutes without payment)
  static bool isBookingVisible(Booking booking, DateTime now) {
    if (booking.status == BookingStatus.cancelled) return false;
    if (booking.status == BookingStatus.pending) {
      return !isPendingBookingExpired(booking.createdAt, now);
    }
    return true;
  }
}
