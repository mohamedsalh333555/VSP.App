import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/booking/booking_domain_rules.dart';

void main() {
  group('Manual booking payment normalization', () {
    test('rejects non-finite and negative monetary inputs', () {
      for (final values in <(double, double)>[
        (double.nan, 100),
        (double.infinity, 100),
        (double.negativeInfinity, 100),
        (50, double.nan),
        (50, double.infinity),
        (50, double.negativeInfinity),
        (-1, 100),
        (50, -100),
        (50, 0),
      ]) {
        final result = BookingDomainRules.normalizeManualBookingPayment(
          depositPaid: values.$1,
          totalPrice: values.$2,
          currentIsPaid: false,
          currentIsDepositPaid: false,
          currentPaymentStatus: 'unpaid',
        );
        expect(result.isPaid, isFalse);
        expect(result.isDepositPaid, isFalse);
        expect(result.paymentStatus, 'unpaid');
      }
    });

    test('valid full and partial deposits retain expected statuses', () {
      final partial = BookingDomainRules.normalizeManualBookingPayment(
        depositPaid: 50,
        totalPrice: 100,
        currentIsPaid: false,
        currentIsDepositPaid: false,
        currentPaymentStatus: 'unpaid',
      );
      expect(partial.paymentStatus, 'deposit_paid');
      expect(partial.isDepositPaid, isTrue);
      expect(partial.isPaid, isFalse);

      final full = BookingDomainRules.normalizeManualBookingPayment(
        depositPaid: 100,
        totalPrice: 100,
        currentIsPaid: false,
        currentIsDepositPaid: false,
        currentPaymentStatus: 'unpaid',
      );
      expect(full.paymentStatus, 'paid');
      expect(full.isPaid, isTrue);
    });
  });
}
