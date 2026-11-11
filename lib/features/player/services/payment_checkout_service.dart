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
    if (!totalPrice.isFinite || totalPrice <= 0 ||
        !depositPaid.isFinite || depositPaid < 0 ||
        depositPaid > totalPrice) {
      throw ArgumentError('Invalid checkout amount or deposit');
    }
    if (!isFullPayment && needsDeposit && depositPaid > 0) {
      return depositPaid;
    }
    return totalPrice;
  }

  /// Returns the corresponding Paymob integration ID based on selected payment method.
  static String getIntegrationId(String method) {
    switch (method.toLowerCase().trim()) {
      case 'wallet':
        return AppConfig.paymobWalletIntegrationId;
      case 'card':
        return AppConfig.paymobCardIntegrationId;
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported checkout method');
    }
  }

  /// Generates a unique tracking payment reference ID for the Paymob transaction.
  static String generatePaymentReference({
    required bool isTournamentPayment,
    String? playerTeamId,
    String? bookingId,
    required int timestampMs,
  }) {
    final normalizedBookingId = bookingId?.trim();
    if (isTournamentPayment) {
      if (normalizedBookingId != null &&
          (normalizedBookingId.startsWith('LEAGUE_') ||
              normalizedBookingId.startsWith('TOURN_'))) {
        return normalizedBookingId;
      }
      final teamId = (playerTeamId != null && playerTeamId.trim().isNotEmpty)
          ? playerTeamId.trim()
          : 'TEAM';
      return 'TOURN_${teamId}_$timestampMs';
    }
    return normalizedBookingId != null && normalizedBookingId.isNotEmpty
        ? normalizedBookingId
        : 'BK_$timestampMs';
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
    final s = status?.toLowerCase().trim();
    final p = paymentStatus?.toLowerCase().trim();

    // Booking is confirmed through electronic payment (either full payment 'paid'
    // or deposit payment 'partially_paid') only when server booking status is confirmed.
    // 'pending + partially_paid' must NEVER be treated as confirmed booking success.
    if (s == 'confirmed') {
      return p == 'paid' || p == 'partially_paid';
    }
    // A paid flag without a confirmed server booking is not payment proof.
    // Keep unknown/missing booking status in the uncertain state.
    return false;
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
