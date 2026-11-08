import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gateway initialization errors restore UI and stop webhook timeout', () {
    final source = File(
      'lib/features/player/screens/payment_gateway_screen.dart',
    ).readAsStringSync();
    final request = source.indexOf('paymobUrl = await PaymentCheckoutService.requestPaymobCheckoutUrl(');
    final recovery = source.indexOf("debugPrint('Paymob checkout initialization failed:");
    final cancel = source.indexOf('_coordinator.cancelWebhookTimeout();', recovery);
    final loading = source.indexOf('_isLoading = false;', cancel);
    final waiting = source.indexOf('_isAwaitingWebhook = false;', cancel);
    final message = source.indexOf('kind.userMessage(arabic:', recovery);
    expect(request, greaterThanOrEqualTo(0));
    expect(recovery, greaterThan(request));
    expect(cancel, greaterThan(recovery));
    expect(loading, greaterThan(cancel));
    expect(waiting, greaterThan(cancel));
    expect(message, greaterThan(waiting));
  });
}
