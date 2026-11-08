import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payment screen uses reconciled failure messages rather than raw gateway text', () {
    final source = File(
      'lib/features/player/screens/payment_gateway_screen.dart',
    ).readAsStringSync();
    expect(source, contains('PaymentFailureKind.unknown.userMessage(arabic: isArabic)'));
    expect(source, contains('PaymentFailureKind.providerUnavailable.userMessage(arabic: isArabic)'));
    expect(source, contains('payment_failure_classifier.dart'));
    expect(source, isNot(contains('Payment was not completed. You can try again anytime.')));
  });
}
