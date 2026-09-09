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
  }) {
    if (needsDeposit && depositPaid > 0) {
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
    return status == 'confirmed' || paymentStatus == 'paid';
  }
}
