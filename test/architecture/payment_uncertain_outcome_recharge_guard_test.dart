import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uncertain Paymob outcomes cannot immediately initiate another charge', () {
    final source = File(
      'lib/features/player/screens/payment_gateway_screen.dart',
    ).readAsStringSync();
    expect(source, contains('bool _paymentOutcomeUncertain = false;'));
    final checkout = source.indexOf('Future<void> _startPaymobCheckout() async');
    final guard = source.indexOf('if (_paymentOutcomeUncertain)', checkout);
    final request = source.indexOf('requestPaymobCheckoutUrl(', checkout);
    expect(guard, greaterThan(checkout));
    expect(request, greaterThan(guard));
    expect(source, contains('_paymentOutcomeUncertain = true;'));
    expect(source, contains('if (kind.requiresStatusReconciliation)'));
  });
}
