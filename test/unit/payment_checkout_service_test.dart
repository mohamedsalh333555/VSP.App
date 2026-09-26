import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/config/app_config.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/services/payment_checkout_service.dart';

void main() {
  group('PaymentCheckoutService Tests', () {
    test('calculateBasePayableAmount returns deposit when deposit required and > 0', () {
      final amount = PaymentCheckoutService.calculateBasePayableAmount(
        needsDeposit: true,
        depositPaid: 150.0,
        totalPrice: 400.0,
      );
      expect(amount, 150.0);
    });

    test('calculateBasePayableAmount returns totalPrice when deposit is not required or 0', () {
      final amount1 = PaymentCheckoutService.calculateBasePayableAmount(
        needsDeposit: false,
        depositPaid: 0.0,
        totalPrice: 400.0,
      );
      expect(amount1, 400.0);

      final amount2 = PaymentCheckoutService.calculateBasePayableAmount(
        needsDeposit: true,
        depositPaid: 0.0,
        totalPrice: 350.0,
      );
      expect(amount2, 350.0);
    });

    test('calculateBasePayableAmount returns totalPrice when isFullPayment is true even if needsDeposit is true', () {
      final amount = PaymentCheckoutService.calculateBasePayableAmount(
        needsDeposit: true,
        depositPaid: 150.0,
        totalPrice: 400.0,
        isFullPayment: true,
      );
      expect(amount, 400.0);
    });

    test('getIntegrationId returns wallet vs card integration ID accurately', () {
      expect(
        PaymentCheckoutService.getIntegrationId('wallet'),
        AppConfig.paymobWalletIntegrationId,
      );
      expect(
        PaymentCheckoutService.getIntegrationId('card'),
        AppConfig.paymobCardIntegrationId,
      );
    });

    test('generatePaymentReference formats tournament and pitch references correctly', () {
      final tournRef = PaymentCheckoutService.generatePaymentReference(
        isTournamentPayment: true,
        playerTeamId: 'team_abc_123',
        bookingId: 'bk_999',
        timestampMs: 1700000000000,
      );
      expect(tournRef, 'TOURN_team_abc_123_1700000000000');

      final tournRefFallback = PaymentCheckoutService.generatePaymentReference(
        isTournamentPayment: true,
        playerTeamId: null,
        bookingId: 'bk_999',
        timestampMs: 1700000000000,
      );
      expect(tournRefFallback, 'TOURN_TEAM_1700000000000');

      final bookingRef = PaymentCheckoutService.generatePaymentReference(
        isTournamentPayment: false,
        bookingId: 'bk_real_123',
        timestampMs: 1700000000000,
      );
      expect(bookingRef, 'bk_real_123');

      final fallbackBookingRef = PaymentCheckoutService.generatePaymentReference(
        isTournamentPayment: false,
        bookingId: null,
        timestampMs: 1700000000000,
      );
      expect(fallbackBookingRef, 'BK_1700000000000');
    });

    test('shouldCleanupStaleBookings allows cleanup only on non-tournament and new bookings', () {
      expect(
        PaymentCheckoutService.shouldCleanupStaleBookings(
          isTournamentPayment: true,
          existingBookingId: null,
        ),
        isFalse,
      );
      expect(
        PaymentCheckoutService.shouldCleanupStaleBookings(
          isTournamentPayment: false,
          existingBookingId: 'existing_123',
        ),
        isFalse,
      );
      expect(
        PaymentCheckoutService.shouldCleanupStaleBookings(
          isTournamentPayment: false,
          existingBookingId: null,
        ),
        isTrue,
      );
    });

    test('isPaymentConfirmed accepts only server-paid state', () {
      expect(PaymentCheckoutService.isPaymentConfirmed(paymentStatus: 'paid'), isTrue);
      expect(PaymentCheckoutService.isPaymentConfirmed(paymentStatus: 'partially_paid'), isFalse);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'pending', paymentStatus: 'pending'), isFalse);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: null, paymentStatus: null), isFalse);
    });

    test('preparePendingDraft sets status to pending and method to paymob', () {
      final now = DateTime(2026, 9, 9, 20, 0);
      final draft = BookingDraft(
        stadiumId: 'std-123',
        stadiumName: 'Al Ahly Arena',
        stadiumImageUrl: '',
        ownerId: 'owner-456',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        bookingType: BookingType.openJoin,
        isPrivate: false,
        rentBall: false,
        totalPrice: 400.0,
        currency: 'EGP',
        depositPaid: 100.0,
      );

      final prepared = PaymentCheckoutService.preparePendingDraft(draft);
      expect(prepared.paymentStatus, 'pending');
      expect(prepared.paymentMethod, 'paymob');
      expect(prepared.isPaid, isFalse);
    });
  });
}
