import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/payment_failure_classifier.dart';

void main() {
  test('classifies user cancellation without suggesting reconciliation', () {
    final kind = PaymentFailureClassifier.classify(code: 'USER_CANCELLED');
    expect(kind, PaymentFailureKind.cancelled);
    expect(kind.isUserCancellation, isTrue);
    expect(kind.requiresStatusReconciliation, isFalse);
  });

  test('classifies timeout and network as uncertain outcomes', () {
    for (final code in ['TIMEOUT', 'SOCKET_EXCEPTION']) {
      expect(
        PaymentFailureClassifier.classify(code: code)
            .requiresStatusReconciliation,
        isTrue,
      );
    }
  });

  test('classifies declined card and authentication failures', () {
    expect(PaymentFailureClassifier.classify(message: 'Card declined'),
        PaymentFailureKind.declined);
    expect(PaymentFailureClassifier.classify(message: '3DS authentication failed'),
        PaymentFailureKind.authentication);
  });

  test('classifies HTTP validation and provider errors', () {
    expect(PaymentFailureClassifier.classify(httpStatus: 422),
        PaymentFailureKind.invalidRequest);
    expect(PaymentFailureClassifier.classify(httpStatus: 503),
        PaymentFailureKind.providerUnavailable);
    expect(PaymentFailureClassifier.classify(httpStatus: 429),
        PaymentFailureKind.providerUnavailable);
  });

  test('HTTP 408 and 504 are uncertain timeouts, not generic provider errors', () {
    for (final status in [408, 504]) {
      final kind = PaymentFailureClassifier.classify(httpStatus: status);
      expect(kind, PaymentFailureKind.timeout);
      expect(kind.requiresStatusReconciliation, isTrue);
    }
  });

  test('HTTP 409 conflict and transport status zero require reconciliation', () {
    expect(PaymentFailureClassifier.classify(httpStatus: 409),
        PaymentFailureKind.duplicate);
    expect(PaymentFailureClassifier.classify(httpStatus: 0),
        PaymentFailureKind.network);
  });

  test('explicit ambiguous HTTP status takes precedence over cancellation text', () {
    expect(PaymentFailureClassifier.classify(httpStatus: 504, message: 'cancelled'),
        PaymentFailureKind.timeout);
    expect(PaymentFailureClassifier.classify(httpStatus: 409, message: 'cancelled'),
        PaymentFailureKind.duplicate);
    expect(PaymentFailureClassifier.classify(httpStatus: 0, message: 'cancelled'),
        PaymentFailureKind.network);
    expect(PaymentFailureClassifier.classify(code: 'USER_CANCELLED'),
        PaymentFailureKind.cancelled);
  });

  test('unknown and duplicate outcomes require reconciliation', () {
    expect(PaymentFailureClassifier.classify().requiresStatusReconciliation,
        isTrue);
    expect(PaymentFailureClassifier.classify(code: 'duplicate').requiresStatusReconciliation,
        isTrue);
  });
  test('every payment failure has safe Arabic and English feedback', () {
    for (final kind in PaymentFailureKind.values) {
      final arabic = kind.userMessage();
      final english = kind.userMessage(arabic: false);
      expect(arabic, isNotEmpty);
      expect(english, isNotEmpty);
      expect(arabic, isNot(equals(english)));
    }
  });

}
