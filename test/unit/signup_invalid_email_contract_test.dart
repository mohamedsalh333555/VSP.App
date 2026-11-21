import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/auth/services/signup_validation_service.dart';
import 'package:vsp_application/l10n/app_localizations_ar.dart';
import 'package:vsp_application/l10n/app_localizations_en.dart';

SignupValidationResult validateEmail(String email) =>
    SignupValidationService.validateForm(
      agreedToTerms: true,
      firstName: 'Mona',
      lastName: 'Ali',
      rawPhone: '01012345678',
      email: email,
      password: 'ValidPassword123!',
      confirmPassword: 'ValidPassword123!',
      dateOfBirth: DateTime(1995, 5, 20),
    );

void main() {
  test('signup rejects obvious malformed email addresses before network calls', () {
    for (final email in [
      'not-an-email',
      'name@',
      '@vspapp.online',
      'name@host',
      'name name@vspapp.online',
      'name@host.',
      'name@@vspapp.online',
      'name@foo.c',
    ]) {
      final result = validateEmail(email);
      expect(result.isValid, false, reason: email);
      expect(result.error, SignupValidationError.invalidEmail,
          reason: email);
    }
  });

  test('common valid plus-addressed emails are accepted after trimming', () {
    for (final email in [
      'mona+1@example.com',
      ' MONA@VSPAPP.ONLINE ',
      'mona.ali@stadium.example',
      'mona@vspapp.online',
    ]) {
      final result = validateEmail(email);
      expect(result.isValid, true, reason: email);
      expect(result.normalizedPhone, '01012345678');
    }
  });

  test('invalid email errors are actionable in Arabic and English', () {
    expect(
      SignupValidationService.getLocalizedErrorMessage(
        SignupValidationError.invalidEmail, AppLocalizationsEn(),
      ),
      AppLocalizationsEn().invalidEmail,
    );
    expect(
      SignupValidationService.getLocalizedErrorMessage(
        SignupValidationError.invalidEmail, AppLocalizationsAr(),
      ),
      AppLocalizationsAr().invalidEmail,
    );
    expect(AppLocalizationsAr().invalidEmail, isNotEmpty);
    expect(AppLocalizationsEn().invalidEmail, isNotEmpty);
  });

  test('registration validates email before the authoritative signup call, without exposing phone accounts', () {
    final screen = File('lib/features/auth/screens/signup_screen.dart')
        .readAsStringSync();
    final validate = screen.indexOf('SignupValidationService.validateForm(');
    final failed = screen.indexOf('if (!validation.isValid)', validate);
    final signup = screen.indexOf('authProvider.signUp(', failed);
    expect(validate, greaterThanOrEqualTo(0));
    expect(failed, greaterThan(validate));
    expect(signup, greaterThan(failed));
    expect(screen, isNot(contains('getUserByPhone(')));
    expect(screen, isNot(contains('UserRepository()')));
    expect(screen, isNot(contains("debugPrintStack(stackTrace: stackTrace)")));
    expect(screen, contains(
      'SignupValidationService.getLocalizedErrorMessage(validation.error!, l10n)',
    ));
  });
}
