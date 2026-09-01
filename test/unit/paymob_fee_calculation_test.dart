import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/paymob_service.dart';

void main() {
  group('Paymob Service Fee Calculations', () {
    test('Zero amount returns 0.0 fee', () {
      expect(PaymobService.calculateServiceFee(0.0), equals(0.0));
      expect(PaymobService.calculateServiceFee(-50.0), equals(0.0));
    });

    test('Standard 100 EGP deposit calculation', () {
      // Formula: (100 * 0.0475) + 3.0 = 4.75 + 3.0 = 7.75 EGP
      final fee = PaymobService.calculateServiceFee(100.0);
      expect(fee, closeTo(7.75, 0.001));
    });

    test('Standard 200 EGP full match price calculation', () {
      // Formula: (200 * 0.0475) + 3.0 = 9.50 + 3.0 = 12.50 EGP
      final fee = PaymobService.calculateServiceFee(200.0);
      expect(fee, closeTo(12.50, 0.001));
    });

    test('Large tournament 1000 EGP registration fee calculation', () {
      // Formula: (1000 * 0.0475) + 3.0 = 47.50 + 3.0 = 50.50 EGP
      final fee = PaymobService.calculateServiceFee(1000.0);
      expect(fee, closeTo(50.50, 0.001));
    });
  });
}
