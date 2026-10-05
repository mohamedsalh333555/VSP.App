import 'auth_registration_form_state.dart';
import 'auth_registration_service.dart';
import '../../utils/app_error_handler.dart';

/// Coordinates OTP sending, verification code matching, password resets, and token verification.
class AuthOtpService {
  final AuthRegistrationService _registrationService;

  AuthOtpService({AuthRegistrationService? registrationService})
      : _registrationService = registrationService ?? AuthRegistrationService();

  /// Sends a real Supabase email verification/OTP message for the active session.
  Future<({bool success, String? error})> sendVerificationCode(
    AuthRegistrationFormState form,
  ) async {
    try {
      final success = await _registrationService.resendOtp();
      return (
        success: success,
        error: success ? null : 'Failed to send verification code',
      );
    } catch (e) {
      return (success: false, error: AppErrorHandler.formatError(e, isArabic: true));
    }
  }

  /// Verifies the entered email OTP against Supabase Auth.
  Future<({bool success, String? error})> verifyCode(
    AuthRegistrationFormState form,
    String code,
  ) async {
    final email = form.email?.trim();
    if (email == null || email.isEmpty || code.trim().isEmpty) {
      return (success: false, error: 'رمز التحقق أو البريد الإلكتروني غير صالح.');
    }
    try {
      final success = await _registrationService.verifyOtp(
        email: email,
        token: code.trim(),
      );
      return (
        success: success,
        error: success ? null : 'رمز التحقق غير صحيح',
      );
    } catch (e) {
      return (success: false, error: AppErrorHandler.formatError(e, isArabic: true));
    }
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
