import '../../../core/config/app_config.dart';
import '../../../core/services/paymob_service.dart';
import '../../../data/models.dart';

/// Pure domain service handling calculation, reference generation, and validation for payment checkout.
class PaymentCheckoutService {
  const PaymentCheckoutService();

  /// Prepares a pending booking draft ready for insertion into the database.
  static BookingDraft preparePendingDraft(BookingDraft draft) {
    return draft.copyWith(
      paymentStatus: 'pending',
      paymentMethod: 'paymob',
      isPaid: false,
    );
  }

  /// Calculates the base payable amount depending on whether a deposit is required.
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

  /// Calculates the final total amount including any gateway processing fees.
  static double calculateTotalAmountWithFees(double baseAmount) {
    return PaymobService.calculateTotalAmount(baseAmount);
  }

  /// Returns the corresponding Paymob integration ID based on selected payment method.
  static String getIntegrationId(String method) {
    if (method == 'wallet') {
      return AppConfig.paymobWalletIntegrationId;
    }
    return AppConfig.paymobCardIntegrationId;
  }

  /// Generates a unique tracking payment reference ID for the Paymob transaction.
  static String generatePaymentReference({
    required bool isTournamentPayment,
    String? playerTeamId,
    String? bookingId,
    required int timestampMs,
  }) {
    if (isTournamentPayment) {
      if (bookingId != null && (bookingId.startsWith('LEAGUE_') || bookingId.startsWith('TOURN_'))) {
        return bookingId;
      }
      final teamId = (playerTeamId != null && playerTeamId.isNotEmpty) ? playerTeamId : 'TEAM';
      return 'TOURN_${teamId}_$timestampMs';
    }
    return bookingId ?? 'BK_$timestampMs';
  }

  /// Determines if stale pending bookings should be cleaned up for the user.
  static bool shouldCleanupStaleBookings({
    required bool isTournamentPayment,
    required String? existingBookingId,
  }) {
    return !isTournamentPayment && existingBookingId == null;
  }

  /// Evaluates whether the booking status indicates successful payment confirmation.
  static bool isPaymentConfirmed({
    String? status,
    String? paymentStatus,
  }) {
    return status == 'confirmed' ||
        paymentStatus == 'paid' ||
        paymentStatus == 'partially_paid';
  }

  /// Requests Paymob checkout URL using standard fee and reference calculations.
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
    final selectedIntegrationId = getIntegrationId(selectedMethod);
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
      integrationId: selectedIntegrationId,
      isTournamentPayment: isTournamentPayment,
      isFullPayment: isFullPayment,
    );
  }
}
