import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/paymob_service.dart';
import 'package:vsp_application/core/utils/vsp_money_formatter.dart';
import 'package:vsp_application/features/player/widgets/payment/payment_security_footer.dart';

void main() {
  const feePolicy = PaymobFeePolicy(
    vspRate: 0.02,
    gatewayRate: 0.0275,
    fixedGatewayFee: 3,
    vspAppliesToCash: false,
    paymobAppliesToElectronic: true,
  );

  test('runtime policy calculates two-decimal charge, not a one-decimal estimate', () {
    expect(feePolicy.isValidForElectronicCheckout, isTrue);
    expect(feePolicy.platformFee(100), 2);
    expect(feePolicy.gatewayFee(100), 5.75);
    expect(feePolicy.serviceFee(100), 7.75);
    expect(feePolicy.total(100), 107.75);
    expect(VSPMoneyFormatter.amount(feePolicy.serviceFee(100)), '7.75');
    expect(VSPMoneyFormatter.amount(feePolicy.total(100)), '107.75');
    expect(VSPMoneyFormatter.amount(107.50), '107.5');
    expect(VSPMoneyFormatter.amount(107), '107');
  });

  for (final language in [true, false]) {
    testWidgets('checkout CTA discloses 107.75 EGP to the cent (' +
        (language ? 'ar' : 'en') + ')', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PaymentSecurityFooter(
              isLoading: false,
              isAwaitingWebhook: false,
              isArabic: language,
              canProceed: true,
              totalAmount: feePolicy.total(100),
              onProceed: () {},
            ),
          ),
        ),
      ));

      expect(find.textContaining('107.75'), findsOneWidget);
      expect(find.textContaining('107.8'), findsNothing);
      expect(find.textContaining('107.7 '), findsNothing);
    });
  }

  test('payment breakdown, countdown and CTA all use the same verified total', () {
    final breakdown = File(
      'lib/features/player/widgets/payment/payment_breakdown_card.dart',
    ).readAsStringSync();
    final countdown = File(
      'lib/features/player/widgets/payment/payment_countdown_header.dart',
    ).readAsStringSync();
    final footer = File(
      'lib/features/player/widgets/payment/payment_security_footer.dart',
    ).readAsStringSync();
    final gateway = File(
      'lib/features/player/screens/payment_gateway_screen.dart',
    ).readAsStringSync();

    expect(breakdown, contains('policy.serviceFee(amountToPay)'));
    expect(breakdown, contains('policy.total(amountToPay)'));
    expect(breakdown, contains('VSPMoneyFormatter.amount(serviceFee)'));
    expect(breakdown, contains('VSPMoneyFormatter.amount(totalWithFees)'));
    expect(breakdown, isNot(contains('serviceFee.toStringAsFixed(1)')));
    expect(breakdown, isNot(contains('totalWithFees.toStringAsFixed(1)')));

    expect(countdown, contains('VSPMoneyFormatter.amount(displayAmount)'));
    expect(countdown, contains('Final total is unavailable until fees are verified.'));
    expect(footer, contains('VSPMoneyFormatter.amount(totalAmount!)'));
    expect(footer, isNot(contains('totalAmount!.toStringAsFixed(1)')));

    expect(gateway, contains('_feePolicy?.isValidForElectronicCheckout == true'));
    expect(gateway, contains('final double? totalWithFees ='));
    expect(gateway, contains('_feePolicy!.total(amountToPay)'));
    expect(gateway, contains('totalAmountWithFees: totalWithFees'));
    expect(gateway, contains('totalAmount: totalWithFees'));
    expect(gateway, contains('!_isFeePolicyLoading'));
    expect(gateway, contains('PaymentBreakdownCard('));
    expect(gateway, contains('PaymentSecurityFooter('));
  });

  test('missing or malformed fee policies fail closed', () {
    final invalid = PaymobFeePolicy.fromMap({
      'booking_vsp_rate': double.nan,
      'booking_paymob_local_rate': 0.0275,
      'booking_paymob_fixed_fee': 3,
      'paymob_applies_to_electronic': true,
    });
    expect(invalid.isValidForElectronicCheckout, isFalse);
    final missing = PaymobFeePolicy.fromMap({});
    expect(missing.isValidForElectronicCheckout, isFalse);
  });
}
