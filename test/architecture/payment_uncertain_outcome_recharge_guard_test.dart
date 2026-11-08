import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkout expiry does not clean up while a payment is unresolved', () {
    final source = File(
      'lib/features/player/screens/payment_gateway_screen.dart',
    ).readAsStringSync();
    final expiry = source.indexOf('onExpired: () async {');
    final guard = source.indexOf(
      '!_paymentCompleted && !_paymentOutcomeUncertain', expiry,
    );
    final awaiting = source.indexOf('!_isAwaitingWebhook && _booking != null', guard);
    final cleanup = source.indexOf('cleanupStaleBookings(', expiry);
    expect(expiry, greaterThanOrEqualTo(0));
    expect(guard, greaterThan(expiry));
    expect(awaiting, greaterThan(guard));
    expect(cleanup, greaterThan(awaiting));
  });

  test('uncertain payment cannot release booking or cancel order', () {
    final source = File(
      'lib/features/player/screens/payment_gateway_screen.dart',
    ).readAsStringSync();
    final cancel = source.indexOf('Future<void> _onCancelAndReleaseBooking(');
    final guard = source.indexOf(
      'if (_paymentOutcomeUncertain || _isAwaitingWebhook)', cancel,
    );
    final release = source.indexOf('await _coordinator.releaseBookingSafely(', cancel);
    expect(cancel, greaterThanOrEqualTo(0));
    expect(guard, greaterThan(cancel));
    expect(release, greaterThan(guard));
  });

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
