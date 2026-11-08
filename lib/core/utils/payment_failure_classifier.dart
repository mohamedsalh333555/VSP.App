/// Normalized payment failure categories for user feedback and safe retry UX.
///
/// This is a client-side classifier only. It never authorizes a charge,
/// confirms payment or changes booking status.
enum PaymentFailureKind {
  cancelled,
  timeout,
  network,
  declined,
  authentication,
  invalidRequest,
  duplicate,
  providerUnavailable,
  unknown,
}

extension PaymentFailureKindExtension on PaymentFailureKind {
  /// Retry means starting a fresh, server-idempotent attempt after checking
  /// the transaction status. Never blindly resubmit a charge.
  bool get requiresStatusReconciliation =>
      this == PaymentFailureKind.timeout ||
      this == PaymentFailureKind.network ||
      this == PaymentFailureKind.duplicate ||
      this == PaymentFailureKind.providerUnavailable ||
      this == PaymentFailureKind.unknown;

  bool get isUserCancellation => this == PaymentFailureKind.cancelled;
}

class PaymentFailureClassifier {
  const PaymentFailureClassifier._();

  static PaymentFailureKind classify({
    String? code,
    String? message,
    int? httpStatus,
  }) {
    final value = '${code ?? ''} ${message ?? ''}'.toLowerCase();
    if (_contains(value, ['cancelled', 'canceled', 'user_cancel', 'إلغاء', 'الغاء'])) {
      return PaymentFailureKind.cancelled;
    }
    if (_contains(value, ['timeout', 'timed out', 'deadline', 'مهلة'])) {
      return PaymentFailureKind.timeout;
    }
    if (_contains(value, ['duplicate', 'already processed', 'idempotency'])) {
      return PaymentFailureKind.duplicate;
    }
    if (_contains(value, ['3ds', '3d secure', 'otp', 'authentication', 'unauthorized']) ||
        httpStatus == 401) {
      return PaymentFailureKind.authentication;
    }
    if (_contains(value, ['declined', 'insufficient funds', 'card rejected', 'مرفوض'])) {
      return PaymentFailureKind.declined;
    }
    if (httpStatus == 400 || httpStatus == 422 ||
        _contains(value, ['invalid request', 'validation'])) {
      return PaymentFailureKind.invalidRequest;
    }
    if (httpStatus == 429 || (httpStatus != null && httpStatus >= 500) ||
        _contains(value, ['unavailable', 'service down', 'rate limit'])) {
      return PaymentFailureKind.providerUnavailable;
    }
    if (_contains(value, ['network', 'socket', 'connection', 'offline', 'dns', 'انترنت'])) {
      return PaymentFailureKind.network;
    }
    return PaymentFailureKind.unknown;
  }

  static bool _contains(String value, List<String> patterns) =>
      patterns.any(value.contains);
}
