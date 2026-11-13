import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/payment_failure_classifier.dart';

void main() {
  test('gateway errors render safe localized user-facing copy', () {
    for (final kind in PaymentFailureKind.values) {
      final arabic = kind.userMessage();
      final english = kind.userMessage(arabic: false);
      expect(arabic, isNotEmpty);
      expect(english, isNotEmpty);
      expect(arabic, isNot(equals(english)));
      expect(arabic, isNot(contains('stacktrace')));
      expect(english.toLowerCase(), isNot(contains('exception:')));
    }
  });

  test('uncertain payment outcomes do not recommend a blind retry', () {
    for (final status in <int>[0, 408, 409, 429, 500, 503, 504]) {
      final kind = PaymentFailureClassifier.classify(
        httpStatus: status, message: 'cancelled',
      );
      expect(kind.requiresStatusReconciliation, isTrue,
          reason: 'HTTP $status is not proof of user cancellation');
      expect(kind.isUserCancellation, isFalse);
    }
  });

  test('payment screen shows safe messages, not gateway exceptions', () {
    final source = File('lib/features/player/screens/payment_gateway_screen.dart')
        .readAsStringSync();
    expect(source, contains('PaymentFailureClassifier.classify('));
    expect(source, contains('kind.userMessage(arabic:'));
    expect(source, contains('PaymentFailureKind.unknown.userMessage('));
    expect(source, contains('PaymentFailureKind.providerUnavailable.userMessage('));
    expect(source, contains('_paymentOutcomeUncertain = true'));
    expect(source, isNot(contains('VSPFeedback.showError(context, error.toString())')));
  });
}
