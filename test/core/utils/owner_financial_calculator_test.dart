import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/owner_financial_calculator.dart';

void main() {
  group('Owner payment source classification', () {
    test('cash at stadium remains cash', () {
      expect(OwnerFinancialCalculator.inferSourceFromMethod('Cash'), 'cash');
      expect(OwnerFinancialCalculator.inferSourceFromMethod('كاش'), 'cash');
    });
    test('mobile wallets do not become cash at stadium', () {
      expect(OwnerFinancialCalculator.inferSourceFromMethod('Vodafone Cash'), 'vodafone_cash');
      expect(OwnerFinancialCalculator.inferSourceFromMethod('فودافون كاش'), 'vodafone_cash');
      expect(OwnerFinancialCalculator.inferSourceFromMethod('InstaPay'), 'instapay');
    });
    test('card and unknown sources are distinct', () {
      expect(OwnerFinancialCalculator.inferSourceFromMethod('Paymob Card'), 'paymob');
      expect(OwnerFinancialCalculator.inferSourceFromMethod('unrecognized'), 'pending');
    });
  });
}
