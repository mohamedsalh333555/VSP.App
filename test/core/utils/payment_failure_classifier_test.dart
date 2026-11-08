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

  test('unknown and duplicate outcomes require reconciliation', () {
    expect(PaymentFailureClassifier.classify().requiresStatusReconciliation,
        isTrue);
    expect(PaymentFailureClassifier.classify(code: 'duplicate').requiresStatusReconciliation,
        isTrue);
  });
}
