import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/providers/auth/auth_otp_service.dart';
import 'package:vsp_application/core/providers/auth/auth_registration_form_state.dart';

void main() {
  group('AuthOtpService Tests', () {
    late AuthOtpService otpService;

    setUp(() {
      otpService = AuthOtpService();
    });

    test('sendVerificationCode no longer invents a local verification code', () async {
      final form = AuthRegistrationFormState();
      final res = await otpService.sendVerificationCode(form);
      expect(form.verificationCode, isNull);
      expect(res.success, isFalse);
      expect(res.error, isNotNull);
    });

    test('verifyCode requires an email before server verification', () async {
      final form = AuthRegistrationFormState();
      final res = await otpService.verifyCode(form, '654321');
      expect(res.success, isFalse);
      expect(res.error, isNotNull);
    });

    
  });
}
