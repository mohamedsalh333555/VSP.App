import 'auth_registration_form_state.dart';
import 'auth_registration_service.dart';

/// Coordinates OTP sending, verification code matching, password resets, and token verification.
class AuthOtpService {
  final AuthRegistrationService _registrationService;

  AuthOtpService({AuthRegistrationService? registrationService})
      : _registrationService = registrationService ?? AuthRegistrationService();

  /// Mock verification code sender (e.g. for development or testing).
  Future<({bool success, String? error})> sendVerificationCode(AuthRegistrationFormState form) async {
    await Future.delayed(const Duration(seconds: 1));
    form.verificationCode = '123456';
    return (success: true, error: null);
  }

  /// Validates entered code against saved form verification code.
  ({bool success, String? error}) verifyCode(AuthRegistrationFormState form, String code) {
    final match = code == form.verificationCode && form.verificationCode != null;
    return (success: match, error: match ? null : 'رمز التحقق غير صحيح');
  }

  /// Sends password reset instructions to user's email.
  Future<({bool success, String? error})> resetPassword(String email) async {
    final ok = await _registrationService.resetPassword(email);
    return (success: ok, error: ok ? null : 'Failed to send password reset email');
  }

  /// Verifies OTP token sent to user email.
  Future<({bool success, String? error})> verifyOtp({required String email, required String token}) async {
    final ok = await _registrationService.verifyOtp(email: email, token: token);
    return (success: ok, error: ok ? null : 'Failed to verify OTP');
  }

  /// Resends OTP to active session email.
  Future<bool> resendOtp() => _registrationService.resendOtp();
}
