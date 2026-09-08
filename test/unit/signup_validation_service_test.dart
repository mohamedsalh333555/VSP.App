import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/auth/services/signup_validation_service.dart';

void main() {
  group('SignupValidationService Unit Tests', () {
    test('validateForm fails if terms are not agreed to', () {
      final res = SignupValidationService.validateForm(
        agreedToTerms: false,
        firstName: 'Ahmed',
        lastName: 'Ali',
        rawPhone: '01012345678',
        email: 'ahmed@test.com',
        password: 'Password123!',
        confirmPassword: 'Password123!',
        dateOfBirth: DateTime(2000, 1, 1),
      );

      expect(res.isValid, isFalse);
      expect(res.error, equals(SignupValidationError.pleaseAgreeToTerms));
    });

    test('validateForm fails if any required field is empty', () {
      final res = SignupValidationService.validateForm(
        agreedToTerms: true,
        firstName: '',
        lastName: 'Ali',
        rawPhone: '01012345678',
        email: 'ahmed@test.com',
        password: 'Password123!',
        confirmPassword: 'Password123!',
        dateOfBirth: DateTime(2000, 1, 1),
      );

      expect(res.isValid, isFalse);
      expect(res.error, equals(SignupValidationError.fillAllFields));
    });

    test('validateForm fails if date of birth is null', () {
      final res = SignupValidationService.validateForm(
        agreedToTerms: true,
        firstName: 'Ahmed',
        lastName: 'Ali',
        rawPhone: '01012345678',
        email: 'ahmed@test.com',
        password: 'Password123!',
        confirmPassword: 'Password123!',
        dateOfBirth: null,
      );

      expect(res.isValid, isFalse);
      expect(res.error, equals(SignupValidationError.pleaseEnterDob));
    });

    test('validateForm fails on invalid Egyptian phone format', () {
      final res = SignupValidationService.validateForm(
        agreedToTerms: true,
        firstName: 'Ahmed',
        lastName: 'Ali',
        rawPhone: '0233445566', // Landline, not 01 mobile
        email: 'ahmed@test.com',
        password: 'Password123!',
        confirmPassword: 'Password123!',
        dateOfBirth: DateTime(2000, 1, 1),
      );

      expect(res.isValid, isFalse);
      expect(res.error, equals(SignupValidationError.invalidPhone));
    });

    test('validateForm fails on password mismatch or short password', () {
      final mismatch = SignupValidationService.validateForm(
        agreedToTerms: true,
        firstName: 'Ahmed',
        lastName: 'Ali',
        rawPhone: '01012345678',
        email: 'ahmed@test.com',
        password: 'Password123!',
        confirmPassword: 'Password999!',
        dateOfBirth: DateTime(2000, 1, 1),
      );
      expect(mismatch.error, equals(SignupValidationError.passwordMismatch));

      final tooShort = SignupValidationService.validateForm(
        agreedToTerms: true,
        firstName: 'Ahmed',
        lastName: 'Ali',
        rawPhone: '01012345678',
        email: 'ahmed@test.com',
        password: '123',
        confirmPassword: '123',
        dateOfBirth: DateTime(2000, 1, 1),
      );
      expect(tooShort.error, equals(SignupValidationError.passwordTooShort));
    });

    test('validateForm succeeds on completely valid inputs', () {
      final res = SignupValidationService.validateForm(
        agreedToTerms: true,
        firstName: 'Mohamed',
        lastName: 'Salah',
        rawPhone: '+201099887766',
        email: 'salah@vsp.com',
        password: 'StrongPassword123!',
        confirmPassword: 'StrongPassword123!',
        dateOfBirth: DateTime(1995, 5, 20),
      );

      expect(res.isValid, isTrue);
      expect(res.error, isNull);
      expect(res.fullName, equals('Mohamed Salah'));
      expect(res.normalizedPhone, equals('01099887766'));
    });

    test('calculatePasswordStrength evaluates score, label, and colors', () {
      final weak = SignupValidationService.calculatePasswordStrength('abc');
      expect(weak.score, equals(0.0));
      expect(weak.label, equals('Weak'));

      final medium = SignupValidationService.calculatePasswordStrength('abcdef12');
      expect(medium.score, greaterThan(0.4));
      expect(medium.label, equals('Medium'));

      final strong = SignupValidationService.calculatePasswordStrength('Abcdef123!');
      expect(strong.score, greaterThanOrEqualTo(0.8));
      expect(strong.label, equals('Strong'));
    });

    test('buildUserDataPayload sets role-specific positions properly', () {
      final playerPayload = SignupValidationService.buildUserDataPayload(
        fullName: 'Player One',
        normalizedPhone: '01011112222',
        isOwner: false,
        selectedPosition: 'ST',
        dateOfBirth: DateTime.utc(2000, 1, 1),
      );
      expect(playerPayload['position'], equals('ST'));
      expect(playerPayload['name'], equals('Player One'));

      final ownerPayload = SignupValidationService.buildUserDataPayload(
        fullName: 'Owner One',
        normalizedPhone: '01011113333',
        isOwner: true,
        selectedPosition: 'ST',
        dateOfBirth: DateTime.utc(1985, 3, 10),
      );
      expect(ownerPayload['position'], isNull);
    });

    test('formatSignupError localizes confirmation email failures correctly', () {
      final arMsg = SignupValidationService.formatSignupError(
        'error with confirmation email send',
        isArabic: true,
      );
      expect(arMsg, contains('تعذر إرسال إيميل التأكيد'));

      final enMsg = SignupValidationService.formatSignupError(
        'unexpected_failure',
        isArabic: false,
      );
      expect(enMsg, contains('Could not send confirmation email'));
    });
  });
}
