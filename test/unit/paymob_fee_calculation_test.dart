import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/paymob_service.dart';

void main() {
  group('Paymob Service Fee & Commission Split Calculations', () {
    test('Zero amount returns 0.0 fee and shares', () {
      expect(PaymobService.calculateServiceFee(0.0), equals(0.0));
      expect(PaymobService.calculatePlatformShare(0.0), equals(0.0));
      expect(PaymobService.calculateGatewayShare(0.0), equals(0.0));
    });

    test('100 EGP exact commission split: 2% Platform vs (2.75% + 3 EGP) Paymob Gateway', () {
      const baseAmount = 100.0;

      // 1. Platform Owner Share (2.0%): Exactly 2.00 EGP
      final platformShare = PaymobService.calculatePlatformShare(baseAmount);
      expect(platformShare, equals(2.00));

      // 2. Paymob Gateway Share (2.75% + 3.0 EGP): Exactly 5.75 EGP
      final gatewayShare = PaymobService.calculateGatewayShare(baseAmount);
      expect(gatewayShare, equals(5.75));

      // 3. Total Service Fee paid by customer: 2.00 + 5.75 = 7.75 EGP
      final totalServiceFee = PaymobService.calculateServiceFee(baseAmount);
      expect(totalServiceFee, equals(7.75));
      expect(totalServiceFee, equals(platformShare + gatewayShare));

      // 4. Total customer checkout amount: 100 + 7.75 = 107.75 EGP
      final totalAmount = PaymobService.calculateTotalAmount(baseAmount);
      expect(totalAmount, equals(107.75));
    });

    test('200 EGP exact commission split', () {
      const baseAmount = 200.0;

      // Platform share (2%): 4.00 EGP
      expect(PaymobService.calculatePlatformShare(baseAmount), equals(4.00));

      // Gateway share (2.75% + 3 EGP): 5.50 + 3.00 = 8.50 EGP
      expect(PaymobService.calculateGatewayShare(baseAmount), equals(8.50));

      // Total fee: 4.00 + 8.50 = 12.50 EGP
      expect(PaymobService.calculateServiceFee(baseAmount), equals(12.50));
    });

    test('1000 EGP tournament registration split', () {
      const baseAmount = 1000.0;

      // Platform share (2%): 20.00 EGP
      expect(PaymobService.calculatePlatformShare(baseAmount), equals(20.00));

      // Gateway share (2.75% + 3 EGP): 27.50 + 3.00 = 30.50 EGP
      expect(PaymobService.calculateGatewayShare(baseAmount), equals(30.50));

      // Total fee: 20.00 + 30.50 = 50.50 EGP
      expect(PaymobService.calculateServiceFee(baseAmount), equals(50.50));
    });
  });
}
