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
    test('supported cash vs digital settlement method strings remain distinct', () {
      for (final value in ['Cash', 'كاش', 'نقدي', 'cash_on_arrival', 'كاش عند الملعب', 'دفع نقدي']) {
        expect(OwnerFinancialCalculator.inferSourceFromMethod(value), 'cash',
            reason: 'Venue-collected cash: $value');
      }
      for (final value in ['wallet', 'visa', 'MasterCard', 'Meeza',
        'بطاقة ائتمان', 'Paymob wallet']) {
        expect(OwnerFinancialCalculator.inferSourceFromMethod(value), 'paymob',
            reason: 'Paymob electronic channel: $value');
      }
      for (final value in ['bank_transfer', 'Bank Transfer', 'تحويل بنكي']) {
        expect(OwnerFinancialCalculator.inferSourceFromMethod(value), 'bank_transfer',
            reason: 'Bank transfer is not pitch cash: $value');
      }
      for (final value in ['Vodafone Cash', 'فودافون كاش']) {
        expect(OwnerFinancialCalculator.inferSourceFromMethod(value), 'vodafone_cash',
            reason: 'Mobile wallet is not cash collected at stadium: $value');
      }
      expect(OwnerFinancialCalculator.inferSourceFromMethod('InstaPay'), 'instapay');
      for (final value in ['', 'cash app unknown', 'unknown']) {
        expect(OwnerFinancialCalculator.inferSourceFromMethod(value), 'pending',
            reason: 'Unverified payment method must not be assumed cash: $value');
      }
    });
  });
}
