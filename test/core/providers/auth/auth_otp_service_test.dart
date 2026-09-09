import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/providers/auth/auth_otp_service.dart';
import 'package:vsp_application/core/providers/auth/auth_registration_form_state.dart';

void main() {
  group('AuthOtpService Tests', () {
    late AuthOtpService otpService;

    setUp(() {
      otpService = AuthOtpService();
    });

    test('sendVerificationCode sets verificationCode to 123456 and returns success', () async {
      final form = AuthRegistrationFormState();
      final res = await otpService.sendVerificationCode(form);
      expect(res.success, isTrue);
      expect(res.error, isNull);
      expect(form.verificationCode, '123456');
    });

    test('verifyCode validates matching and non-matching codes', () {
      final form = AuthRegistrationFormState();
      form.verificationCode = '654321';

      final successRes = otpService.verifyCode(form, '654321');
      expect(successRes.success, isTrue);
      expect(successRes.error, isNull);

      final failRes = otpService.verifyCode(form, '000000');
      expect(failRes.success, isFalse);
      expect(failRes.error, isNotNull);
    });

    test('verifyCode returns false when verificationCode is null', () {
      final form = AuthRegistrationFormState();
      final res = otpService.verifyCode(form, '123456');
      expect(res.success, isFalse);
      expect(res.error, isNotNull);
    });
  });
}
