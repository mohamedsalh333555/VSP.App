import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/platform_fee_service.dart';

PlatformFeeConfig contractFeeConfig() => PlatformFeeConfig(
  vspRate: 0.02,
  paymobRate: 0.024,
  paymobLocalRate: 0.024,
  paymobForeignRate: 0.026,
  paymobWalletRate: 0.024,
  paymobFixedFee: 3.0,
);

void main() {
  group('Authoritative booking fee configuration', () {
    test('100 EGP local card uses VSP 2% + Paymob 2.4% + 3 EGP', () {
      final config = contractFeeConfig();

      expect(config.calculateVspFee(100), 2.00);
      expect(config.calculateGatewayFee(100, 'card'), 5.40);
      expect(config.calculateTotalFees(100, 'card'), 7.40);
      expect(config.calculateTotalAmount(100, 'card'), 107.40);
    });

    test('100 EGP wallet uses the same Paymob rate as local cards', () {
      final config = contractFeeConfig();

      expect(config.calculateGatewayFee(100, 'wallet'), 5.40);
      expect(config.calculateTotalFees(100, 'wallet'), 7.40);
      expect(config.calculateTotalAmount(100, 'wallet'), 107.40);
    });

    test('100 EGP foreign card uses 2.6% + 3 EGP', () {
      final config = contractFeeConfig();

      expect(config.calculateGatewayFee(100, 'foreign_card'), 5.60);
      expect(config.calculateTotalFees(100, 'foreign_card'), 7.60);
      expect(config.calculateTotalAmount(100, 'foreign_card'), 107.60);
    });

    test('250 EGP local card rounds to 14.00 EGP total fees', () {
      final config = contractFeeConfig();

      expect(config.calculateVspFee(250), 5.00);
      expect(config.calculateGatewayFee(250, 'card'), 9.00);
      expect(config.calculateTotalFees(250, 'card'), 14.00);
      expect(config.calculateTotalAmount(250, 'card'), 264.00);
    });

    test('Zero amount has zero variable and fixed fee', () {
      final config = contractFeeConfig();

      expect(config.calculateVspFee(0), 0.0);
      expect(config.calculateGatewayFee(0, 'card'), 3.0);
      expect(config.calculateTotalFees(0, 'card'), 3.0);
    });
  });
}
