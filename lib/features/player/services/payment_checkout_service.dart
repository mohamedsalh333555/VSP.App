import 'package:uuid/uuid.dart';
import '../../../core/services/paymob_service.dart';
import '../../../data/models.dart';

/// Client adapter around a server-authoritative payment flow.
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

  /// Correlation reference only; server remains authoritative for accounting.
  static String generatePaymentReference({
    required bool isTournamentPayment,
    String? bookingId,
  }) {
    if (bookingId != null && bookingId.isNotEmpty) return bookingId;
    if (isTournamentPayment) return 'TOURN_\${const Uuid().v4()}';
    throw StateError('A booking ID is required for a booking payment.');
  }

  static bool shouldCleanupStaleBookings({
    required bool isTournamentPayment,
    required String? existingBookingId,
  }) {
    return !isTournamentPayment && existingBookingId == null;
  }

  static bool isPaymentConfirmed({
    String? status,
    String? paymentStatus,
  }) {
    return status == 'confirmed' ||
        paymentStatus == 'paid' ||
        paymentStatus == 'partially_paid';
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
      bookingId: bookingId,
    );

    return PaymobService.getCheckoutUrlFromServer(
      amountInEgp: baseAmount,
      bookingId: paymentRefId,
      userEmail: userEmail,
      userName: userName,
      userPhone: userPhone,
      paymentMethod: selectedMethod,
      isTournamentPayment: isTournamentPayment,
      isFullPayment: isFullPayment,
    );
  }
}
