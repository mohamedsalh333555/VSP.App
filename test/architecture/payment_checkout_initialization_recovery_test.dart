import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gateway initialization errors restore UI and stop webhook timeout', () {
    final source = File(
      'lib/features/player/screens/payment_gateway_screen.dart',
    ).readAsStringSync();
    final request = source.indexOf(
      'paymobUrl = await PaymentCheckoutService.requestPaymobCheckoutUrl(',
    );
    expect(request, greaterThanOrEqualTo(0));

    // The diagnostic was deliberately redacted. Do not locate the recovery
    // path by its previous sensitive debug message.
    final recovery = source.indexOf('} catch (error) {', request);
    expect(recovery, greaterThan(request));
    final redactedLog = source.indexOf(
      "debugPrint('Paymob checkout initialization failed (details redacted)');",
      recovery,
    );
    final accountGuard = source.indexOf(
      'if (!mounted || _hasAccountChanged',
      recovery,
    );
    final cancel = source.indexOf(
      '_coordinator.cancelWebhookTimeout();',
      accountGuard,
    );
    final loading = source.indexOf('_isLoading = false;', cancel);
    final waiting = source.indexOf('_isAwaitingWebhook = false;', cancel);
    final message = source.indexOf('kind.userMessage(arabic:', waiting);
    final end = source.indexOf('if (paymobUrl != null', message);

    expect(redactedLog, greaterThan(recovery));
    expect(accountGuard, greaterThan(redactedLog));
    expect(cancel, greaterThan(accountGuard));
    expect(loading, greaterThan(cancel));
    expect(waiting, greaterThan(cancel));
    expect(message, greaterThan(waiting));
    expect(end, greaterThan(message));

    // Payment-provider exception data may be classified internally, but it
    // must never be interpolated into a diagnostic or user-facing message.
    final recoverySource = source.substring(recovery, end);
    expect(recoverySource, isNot(contains('debugPrint(error')));
    expect(recoverySource, isNot(contains('debugPrint(\$error')));
    expect(recoverySource, contains('PaymentFailureClassifier.classify('));
    expect(recoverySource, contains('VSPFeedback.showError('));
  });
}
