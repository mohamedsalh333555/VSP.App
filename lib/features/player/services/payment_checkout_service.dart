import '../../../core/services/paymob_service.dart';
import '../../../data/models.dart';

/// Domain adapter for the Paymob checkout flow.
///
/// The client only determines the principal amount to be paid (full booking
/// or required deposit). VSP and gateway fees are calculated authoritatively
/// by the backend from public.platform_fee_config.
class PaymentCheckoutService {
  const PaymentCheckoutService();

  static BookingDraft preparePendingDraft(BookingDraft draft) {
    return draft.copyWith(
      paymentStatus: 'pending',
      paymentMethod: 'paymob',
      isPaid: false,
    );
  }

  static double calculateBasePayableAmount({
    required bool needsDeposit,
    required double depositPaid,
    required double totalPrice,
    bool isFullPayment = false,
  }) {
    if (!isFullPayment && needsDeposit && depositPaid > 0) {
      return depositPaid;
    }
    return totalPrice;
  }

  static String generatePaymentReference({
    required bool isTournamentPayment,
    String? playerTeamId,
    String? bookingId,
    required int timestampMs,
  }) {
    if (isTournamentPayment) {
      // Paid tournament flows must preserve the server-created order reference.
      if (bookingId == null || bookingId.isEmpty) {
        throw ArgumentError(
          'Tournament payments require a server-created order reference.',
        );
      }
      return bookingId;
    }
    return bookingId ?? 'BK_$timestampMs';
  }

  static bool shouldCleanupStaleBookings({
    required bool isTournamentPayment,
    required String? existingBookingId,
  }) {
    return !isTournamentPayment && existingBookingId == null;
  }

  /// Only an explicitly paid payment is a successful payment completion.
  ///
  /// Booking status is intentionally not treated as payment confirmation because
  /// deposit bookings may be confirmed while their payment status is
  /// partially_paid.
  static bool isPaymentConfirmed({
    String? status,
    String? paymentStatus,
  }) {
    return paymentStatus == 'paid';
  }

  static Future<String?> requestPaymobCheckoutUrl({
    required BookingDraft draft,
    required bool isTournamentPayment,
    String? bookingId,
    required String userEmail,
    required String userName,
    required String userPhone,
    bool isFullPayment = false,
  }) async {
    final baseAmount = calculateBasePayableAmount(
      needsDeposit: draft.needsDeposit,
      depositPaid: draft.depositPaid,
      totalPrice: draft.totalPrice,
      isFullPayment: isFullPayment,
    );

    final paymentRefId = generatePaymentReference(
      isTournamentPayment: isTournamentPayment,
      playerTeamId: draft.playerTeamId,
      bookingId: bookingId,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    return PaymobService.getCheckoutUrlFromServer(
      amountInEgp: baseAmount,
      bookingId: paymentRefId,
      userEmail: userEmail,
      userName: userName,
      userPhone: userPhone,
      isTournamentPayment: isTournamentPayment,
      isFullPayment: isFullPayment,
    );
  }
}
