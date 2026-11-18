/// Neutral recovery acknowledgement. Never exposes whether an email address
/// exists, irrespective of the backend's result or transport failure.
abstract final class PasswordResetPrivacyMessage {
  static String acknowledgement({required bool isArabic}) => isArabic
      ? 'لو البريد مسجل وطلب الاستعادة وصل، هتوصلك تعليمات على البريد.'
      : 'If the email is registered and the request was received, recovery instructions will be sent.';
}
