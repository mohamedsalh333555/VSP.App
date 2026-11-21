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

    test('rejects invalid amounts before requesting a payment session', () {
      for (final amount in <double>[
        -1,
        0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => PaymentCheckoutService.calculateBasePayableAmount(
            needsDeposit: false,
            depositPaid: 0,
            totalPrice: amount,
          ),
          throwsArgumentError,
          reason: 'totalPrice=$amount',
        );
      }
      for (final deposit in <double>[
        -1,
        401,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => PaymentCheckoutService.calculateBasePayableAmount(
            needsDeposit: true,
            depositPaid: deposit,
            totalPrice: 400,
          ),
          throwsArgumentError,
          reason: 'depositPaid=$deposit',
        );
      }
      expect(
        PaymentCheckoutService.calculateBasePayableAmount(
          needsDeposit: true,
          depositPaid: 400,
          totalPrice: 400,
        ),
        400,
      );
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

    test('unsupported payment methods never silently select card checkout', () {
      for (final method in <String>['', 'cash', 'instapay', 'unknown']) {
        expect(
          () => PaymentCheckoutService.getIntegrationId(method),
          throwsArgumentError,
          reason: 'method=$method',
        );
      }
      expect(
        PaymentCheckoutService.getIntegrationId(' WALLET '),
        AppConfig.paymobWalletIntegrationId,
      );
      expect(
        PaymentCheckoutService.getIntegrationId(' CARD '),
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

    test('blank checkout booking references use a nonempty fallback', () {
      for (final bookingId in <String?>[null, '', '   ']) {
        expect(
          PaymentCheckoutService.generatePaymentReference(
            isTournamentPayment: false,
            bookingId: bookingId,
            timestampMs: 1700000000000,
          ),
          'BK_1700000000000',
        );
      }
      expect(
        PaymentCheckoutService.generatePaymentReference(
          isTournamentPayment: false,
          bookingId: '  booking-123  ',
          timestampMs: 1700000000000,
        ),
        'booking-123',
      );
      expect(
        PaymentCheckoutService.generatePaymentReference(
          isTournamentPayment: true,
          bookingId: '  LEAGUE_abc  ',
          timestampMs: 1700000000000,
        ),
        'LEAGUE_abc',
      );
      expect(
        PaymentCheckoutService.generatePaymentReference(
          isTournamentPayment: true,
          playerTeamId: '   ',
          timestampMs: 1700000000000,
        ),
        'TOURN_TEAM_1700000000000',
      );
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

    test('isPaymentConfirmed accepts server-paid and confirmed partially_paid states', () {
      expect(PaymentCheckoutService.isPaymentConfirmed(paymentStatus: 'paid'), isFalse);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'confirmed', paymentStatus: 'paid'), isTrue);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: '', paymentStatus: 'paid'), isFalse);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'cancelled', paymentStatus: 'paid'), isFalse);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'pending', paymentStatus: 'paid'), isFalse);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'confirmed', paymentStatus: 'partially_paid'), isTrue);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'pending', paymentStatus: 'partially_paid'), isFalse);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: 'pending', paymentStatus: 'pending'), isFalse);
      expect(PaymentCheckoutService.isPaymentConfirmed(status: null, paymentStatus: null), isFalse);
    });

    test('reconciliation conflicts never report successful checkout', () {
      for (final state in <String>[
        'unpaid',
        'refund_pending',
        'refunded',
        'refund_failed',
      ]) {
        expect(
          PaymentCheckoutService.isPaymentConfirmed(
            status: 'confirmed',
            paymentStatus: 'paid',
            paymentReconcileState: state,
          ),
          isFalse,
          reason: 'reconcile=$state',
        );
      }
      for (final state in <String>['fully_paid', 'partially_paid']) {
        expect(
          PaymentCheckoutService.isPaymentConfirmed(
            status: 'confirmed',
            paymentStatus: 'paid',
            paymentReconcileState: state,
          ),
          isTrue,
          reason: 'reconcile=$state',
        );
      }
    });

    test('refund lifecycle overrides stale fully paid reconciliation', () {
      for (final status in <String>[
        'refund_pending',
        'refunded',
        'refund_failed',
      ]) {
        expect(
          PaymentCheckoutService.isPaymentConfirmed(
            status: 'confirmed',
            paymentStatus: status,
            paymentReconcileState: 'fully_paid',
          ),
          isFalse,
          reason: 'paymentStatus=$status',
        );
      }
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
