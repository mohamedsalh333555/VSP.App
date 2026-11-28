import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/paymob_service.dart';

void main() {
  group('Paymob Service Fee & Commission Split Calculations', () {
    test('Zero amount returns 0.0 fee and shares', () {
      expect(PaymobService.calculateServiceFee(0.0), equals(0.0));
      expect(PaymobService.calculatePlatformShare(0.0), equals(0.0));
      expect(PaymobService.calculateGatewayShare(0.0), equals(0.0));
    });

    test('100 EGP exact commission split: 5% player + 5% owner + (2.4% + 3 EGP) local/wallet Paymob gross-up', () {
      const baseAmount = 100.0;
      const policy = PaymobFeePolicy(
        vspRate: 0.05,
        ownerVspRate: 0.05,
        gatewayRate: 0.024,
        foreignGatewayRate: 0.026,
        fixedGatewayFee: 3.0,
        vspAppliesToCash: false,
        paymobAppliesToElectronic: true,
        gatewayFeeMode: 'gross_up',
      );

      expect(policy.platformFee(baseAmount), equals(5.00));
      expect(policy.ownerCommission(baseAmount), equals(5.00));
      expect(policy.ownerNet(baseAmount), equals(95.00));
      expect(policy.gatewayFee(baseAmount), equals(5.66));
      expect(policy.total(baseAmount), equals(110.66));
      expect(policy.gatewayFee(baseAmount, isForeign: true), equals(5.88));
      expect(policy.total(baseAmount, isForeign: true), equals(110.88));
    });

    test('200 EGP exact commission split', () {
      const baseAmount = 200.0;

      // Player VSP share (5%): 10.00 EGP
      expect(PaymobService.calculatePlatformShare(baseAmount), equals(10.00));

      // Gateway share (gross-up 2.4% + 3 EGP on 210): (210 + 3) / 0.976 = 218.24 -> 8.24 EGP
      expect(PaymobService.calculateGatewayShare(baseAmount), equals(8.24));

      // Total fee: 10.00 + 8.24 = 18.24 EGP
      expect(PaymobService.calculateServiceFee(baseAmount), equals(18.24));
    });

    test('1000 EGP tournament registration split', () {
      const baseAmount = 1000.0;

      // Player VSP share (5%): 50.00 EGP
      expect(PaymobService.calculatePlatformShare(baseAmount), equals(50.00));

      // Gateway share (gross-up 2.4% + 3 EGP on 1050): (1050 + 3) / 0.976 = 1078.89 -> 28.89 EGP
      expect(PaymobService.calculateGatewayShare(baseAmount), equals(28.89));

      // Total fee: 50.00 + 28.89 = 78.89 EGP
      expect(PaymobService.calculateServiceFee(baseAmount), equals(78.89));
    });
  });
}
