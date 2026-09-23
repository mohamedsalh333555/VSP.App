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
      final teamId = (playerTeamId != null && playerTeamId.isNotEmpty)
          ? playerTeamId
          : 'TEAM';
      return 'TOURN_${teamId}_$timestampMs';
    }
    return bookingId ?? 'BK_$timestampMs';
  }

  static bool shouldCleanupStaleBookings({
    required bool isTournamentPayment,
    required String? existingBookingId,
  }) {
    return !isTournamentPayment && existingBookingId == null;
  }

  /// Only a fully paid booking is a successful payment completion.
  static bool isPaymentConfirmed({
    String? status,
    String? paymentStatus,
  }) {
    return status == 'confirmed' || paymentStatus == 'paid';
  }

  static Future<String?> requestPaymobCheckoutUrl({
    required BookingDraft draft,
    required String selectedMethod,
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
