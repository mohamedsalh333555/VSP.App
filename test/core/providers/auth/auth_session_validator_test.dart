import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/providers/auth/auth_session_validator.dart';
import 'package:vsp_application/core/models/user_model.dart';

void main() {
  group('AuthSessionValidator', () {
    group('isUnregisteredSocialLoginAttempt', () {
      test('returns false when isLoginOnly is false', () {
        expect(
          AuthSessionValidator.isUnregisteredSocialLoginAttempt(
            isLoginOnly: false,
            userData: null,
          ),
          isFalse,
        );
        expect(
          AuthSessionValidator.isUnregisteredSocialLoginAttempt(
            isLoginOnly: false,
            userData: {'phone': ''},
          ),
          isFalse,
        );
      });

      test('returns true when isLoginOnly is true and userData has no phone', () {
        expect(
          AuthSessionValidator.isUnregisteredSocialLoginAttempt(
            isLoginOnly: true,
            userData: null,
          ),
          isTrue,
        );
        expect(
          AuthSessionValidator.isUnregisteredSocialLoginAttempt(
            isLoginOnly: true,
            userData: {'phone': ''},
          ),
          isTrue,
        );
        expect(
          AuthSessionValidator.isUnregisteredSocialLoginAttempt(
            isLoginOnly: true,
            userData: {'phone': '   '},
          ),
          isTrue,
        );
      });

      test('returns false when isLoginOnly is true and valid phone is present', () {
        expect(
          AuthSessionValidator.isUnregisteredSocialLoginAttempt(
            isLoginOnly: true,
            userData: {'phone': '+201234567890'},
          ),
          isFalse,
        );
      });
    });

    group('shouldOverrideOAuthRole', () {
      test('returns false if pendingRole is null', () {
        expect(
          AuthSessionValidator.shouldOverrideOAuthRole(
            pendingRole: null,
            userData: {'role': 'player'},
          ),
          isFalse,
        );
      });

      test('returns false if registration is already complete', () {
        expect(
          AuthSessionValidator.shouldOverrideOAuthRole(
            pendingRole: 'owner',
            userData: {'role': 'player', 'is_registration_complete': true},
          ),
          isFalse,
        );
      });

      test('returns true if role differs and registration is not complete', () {
        expect(
          AuthSessionValidator.shouldOverrideOAuthRole(
            pendingRole: 'owner',
            userData: {'role': 'player', 'is_registration_complete': false},
          ),
          isTrue,
        );
      });

      test('returns false if role is already equal', () {
        expect(
          AuthSessionValidator.shouldOverrideOAuthRole(
            pendingRole: 'player',
            userData: {'role': 'player', 'is_registration_complete': false},
          ),
          isFalse,
        );
      });
    });

    group('isExistingCompleteUser', () {
      test('returns true only when complete and phone non-empty', () {
        expect(
          AuthSessionValidator.isExistingCompleteUser({
            'is_registration_complete': true,
            'phone': '01012345678',
          }),
          isTrue,
        );
        expect(
          AuthSessionValidator.isExistingCompleteUser({
            'isRegistrationComplete': true,
            'phone': '01012345678',
          }),
          isTrue,
        );
        expect(
          AuthSessionValidator.isExistingCompleteUser({
            'is_registration_complete': true,
            'phone': '',
          }),
          isFalse,
        );
        expect(
          AuthSessionValidator.isExistingCompleteUser({
            'is_registration_complete': false,
            'phone': '01012345678',
          }),
          isFalse,
        );
      });
    });

    group('hasValidPhone', () {
      test('checks phone on UserModel correctly', () {
        expect(AuthSessionValidator.hasValidPhone(null), isFalse);

        final emptyPhoneUser = UserModel(
          uid: '1',
          email: 'test@vsp.com',
          name: 'Test',
          phone: '',
          role: 'player',
        );
        expect(AuthSessionValidator.hasValidPhone(emptyPhoneUser), isFalse);

        final validPhoneUser = UserModel(
          uid: '1',
          email: 'test@vsp.com',
          name: 'Test',
          phone: '01012345678',
          role: 'player',
        );
        expect(AuthSessionValidator.hasValidPhone(validPhoneUser), isTrue);
      });
    });

    group('shouldAutoPatchRegistrationComplete', () {
      test('only patches if incomplete AND has valid phone', () {
        expect(AuthSessionValidator.shouldAutoPatchRegistrationComplete(null), isFalse);

        final incompleteWithoutPhone = UserModel(
          uid: '1',
          email: 'test@vsp.com',
          name: 'Test',
          phone: null,
          role: 'player',
          isRegistrationComplete: false,
        );
        expect(
          AuthSessionValidator.shouldAutoPatchRegistrationComplete(incompleteWithoutPhone),
          isFalse,
        );

        final incompleteWithPhone = UserModel(
          uid: '1',
          email: 'test@vsp.com',
          name: 'Test',
          phone: '01012345678',
          role: 'player',
          isRegistrationComplete: false,
        );
        expect(
          AuthSessionValidator.shouldAutoPatchRegistrationComplete(incompleteWithPhone),
          isTrue,
        );

        final completeWithPhone = UserModel(
          uid: '1',
          email: 'test@vsp.com',
          name: 'Test',
          phone: '01012345678',
          role: 'player',
          isRegistrationComplete: true,
        );
        expect(
          AuthSessionValidator.shouldAutoPatchRegistrationComplete(completeWithPhone),
          isFalse,
        );
      });
    });

    group('shouldClearUserTypeForAutoLogin', () {
      test('returns true for complete user with phone', () {
        expect(AuthSessionValidator.shouldClearUserTypeForAutoLogin(null), isFalse);

        final completeUser = UserModel(
          uid: '1',
          email: 'test@vsp.com',
          name: 'Test',
          phone: '01012345678',
          role: 'player',
          isRegistrationComplete: true,
        );
        expect(AuthSessionValidator.shouldClearUserTypeForAutoLogin(completeUser), isTrue);

        final incompleteUser = UserModel(
          uid: '1',
          email: 'test@vsp.com',
          name: 'Test',
          phone: '01012345678',
          role: 'player',
          isRegistrationComplete: false,
        );
        expect(AuthSessionValidator.shouldClearUserTypeForAutoLogin(incompleteUser), isFalse);
      });
    });
  });
}
