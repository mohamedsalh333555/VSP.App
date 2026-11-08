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

  /// Safe, non-technical feedback for the payment UI.
  /// Never display raw gateway messages containing sensitive payment details.
  String userMessage({bool arabic = true}) {
    if (arabic) {
      switch (this) {
        case PaymentFailureKind.cancelled:
          return 'تم إلغاء عملية الدفع.';
        case PaymentFailureKind.timeout:
          return 'انتهت مهلة الدفع. تحقق من حالة العملية قبل المحاولة مرة أخرى.';
        case PaymentFailureKind.network:
          return 'تعذر الاتصال. تحقق من حالة الدفع قبل إعادة المحاولة.';
        case PaymentFailureKind.declined:
          return 'لم تتم الموافقة على الدفع. جرّب وسيلة دفع أخرى.';
        case PaymentFailureKind.authentication:
          return 'تعذر تأكيد عملية الدفع. أعد التحقق من بيانات المصادقة.';
        case PaymentFailureKind.invalidRequest:
          return 'تعذر بدء عملية الدفع. حاول مجددًا أو تواصل مع الدعم.';
        case PaymentFailureKind.duplicate:
          return 'هذه العملية قيد المعالجة بالفعل. تحقق من حالتها أولًا.';
        case PaymentFailureKind.providerUnavailable:
          return 'خدمة الدفع غير متاحة حاليًا. تحقق من حالة العملية لاحقًا.';
        case PaymentFailureKind.unknown:
          return 'تعذر التأكد من نتيجة الدفع. تحقق من حالة العملية قبل إعادة المحاولة.';
      }
    }
    switch (this) {
      case PaymentFailureKind.cancelled:
        return 'Payment was cancelled.';
      case PaymentFailureKind.timeout:
        return 'Payment timed out. Check its status before trying again.';
      case PaymentFailureKind.network:
        return 'Connection failed. Check payment status before retrying.';
      case PaymentFailureKind.declined:
        return 'Payment was declined. Try another payment method.';
      case PaymentFailureKind.authentication:
        return 'Payment authentication failed. Please verify your details.';
      case PaymentFailureKind.invalidRequest:
        return 'Could not start payment. Try again or contact support.';
      case PaymentFailureKind.duplicate:
        return 'This payment is already being processed. Check its status.';
      case PaymentFailureKind.providerUnavailable:
        return 'Payment service is unavailable. Check the status later.';
      case PaymentFailureKind.unknown:
        return 'Payment result is uncertain. Check its status before retrying.';
    }
  }


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
