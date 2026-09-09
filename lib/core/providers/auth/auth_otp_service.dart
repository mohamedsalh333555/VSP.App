import 'auth_registration_form_state.dart';
import 'auth_registration_service.dart';

/// Coordinates OTP sending, verification code matching, password resets, and token verification.
class AuthOtpService {
  final AuthRegistrationService _registrationService;

  AuthOtpService({AuthRegistrationService? registrationService})
      : _registrationService = registrationService ?? AuthRegistrationService();

  /// Mock verification code sender (e.g. for development or testing).
  Future<bool> sendVerificationCode(AuthRegistrationFormState form) async {
    await Future.delayed(const Duration(seconds: 1));
    form.verificationCode = '123456';
    return true;
  }

  /// Validates entered code against saved form verification code.
  bool verifyCode(AuthRegistrationFormState form, String code) {
    return code == form.verificationCode && form.verificationCode != null;
  }

  /// Sends password reset instructions to user's email.
  Future<bool> resetPassword(String email) =>
      _registrationService.resetPassword(email);

  /// Verifies OTP token sent to user email.
  Future<bool> verifyOtp({required String email, required String token}) =>
      _registrationService.verifyOtp(email: email, token: token);

  /// Resends OTP to active session email.
  Future<bool> resendOtp() => _registrationService.resendOtp();
}
