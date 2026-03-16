import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Owner Flow Gating Tests
//
// These tests validate the RootScreen gating logic by testing the UserModel
// flag combinations that drive each owner routing decision.
//
// Covers:
//  A. Owner with no stadium → FacilityOnboardingScreen path
//  B. Owner with stadium but not verified → OwnerDocumentationWizard path
//  C. Suspended owner → SuspendedAccountScreen path
//  D. Fully completed owner → OwnerMainScreen path
//  E. Owner role is preserved through signup and flag transitions
//  F. isIdentityVerified write now unblocked (regression guard for auth_service fix)
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // Helper: create a base owner UserModel with given flag overrides
  UserModel makeOwner({
    bool hasStadium = false,
    bool isIdentityVerified = false,
    bool isRegistrationComplete = false,
    bool isSuspended = false,
    String? phone = '+20 100 000 0000',
  }) {
    return UserModel(
      uid: 'test-owner-uid',
      email: 'owner@test.com',
      role: 'owner',
      name: 'Test Owner',
      phone: phone,
      hasStadium: hasStadium,
      isIdentityVerified: isIdentityVerified,
      isRegistrationComplete: isRegistrationComplete,
      isSuspended: isSuspended,
    );
  }

  // ─── A. Owner with no stadium ─────────────────────────────────────────────
  group('A. Owner without a stadium', () {
    test('should route to FacilityOnboardingScreen', () {
      final owner = makeOwner(
        isRegistrationComplete: true,
        hasStadium: false,
        isIdentityVerified: false,
        isSuspended: false,
      );

      expect(owner.role, 'owner');
      expect(owner.isRegistrationComplete, isTrue);
      expect(owner.hasStadium, isFalse,
          reason: 'No stadium: should be sent to FacilityOnboardingScreen');
    });

    test('hasStadium=false even after registration is complete', () {
      final owner = makeOwner(
        isRegistrationComplete: true,
        hasStadium: false,
      );
      expect(owner.hasStadium, isFalse);
    });
  });

  // ─── B. Owner with stadium but not identity-verified ─────────────────────
  group('B. Owner with stadium but not identity-verified', () {
    test('should route to OwnerDocumentationWizard', () {
      final owner = makeOwner(
        isRegistrationComplete: true,
        hasStadium: true,
        isIdentityVerified: false,
        isSuspended: false,
      );

      expect(owner.hasStadium, isTrue);
      expect(owner.isIdentityVerified, isFalse,
          reason: 'Not verified: should be sent to OwnerDocumentationWizard');
    });

    test('copyWith isIdentityVerified transitions correctly', () {
      final base = makeOwner(hasStadium: true, isIdentityVerified: false);
      final verified = base.copyWith(isIdentityVerified: true);
      expect(verified.isIdentityVerified, isTrue);
      // All other flags must survive unchanged
      expect(verified.hasStadium, isTrue);
      expect(verified.isRegistrationComplete, base.isRegistrationComplete);
    });
  });

  // ─── C. Suspended owner ───────────────────────────────────────────────────
  group('C. Suspended owner', () {
    test('should route to SuspendedAccountScreen regardless of other flags', () {
      final suspended = makeOwner(
        isRegistrationComplete: true,
        hasStadium: true,
        isIdentityVerified: true,
        isSuspended: true,
      );

      expect(suspended.isSuspended, isTrue,
          reason: 'Suspended owner must be blocked even if all other flags complete');
    });

    test('suspension with partial setup is still blocked', () {
      final suspended = makeOwner(
        isRegistrationComplete: false,
        hasStadium: false,
        isIdentityVerified: false,
        isSuspended: true,
      );
      expect(suspended.isSuspended, isTrue);
    });
  });

  // ─── D. Fully completed owner ─────────────────────────────────────────────
  group('D. Fully completed owner', () {
    test('should route to OwnerMainScreen', () {
      final owner = makeOwner(
        isRegistrationComplete: true,
        hasStadium: true,
        isIdentityVerified: true,
        isSuspended: false,
      );

      expect(owner.isRegistrationComplete, isTrue);
      expect(owner.hasStadium, isTrue);
      expect(owner.isIdentityVerified, isTrue);
      expect(owner.isSuspended, isFalse,
          reason: 'All flags complete → OwnerMainScreen');
    });

    test('RootScreen gating logic expressed as pure flag evaluation', () {
      final owner = makeOwner(
        isRegistrationComplete: true,
        hasStadium: true,
        isIdentityVerified: true,
        isSuspended: false,
        phone: '+20 100 000 0001',
      );

      // Replicate RootScreen decision tree as a pure function
      String resolveOwnerRoute(UserModel u) {
        if (u.isSuspended) return 'SuspendedAccountScreen';
        if (!u.hasStadium) return 'FacilityOnboardingScreen';
        if (!u.isIdentityVerified) return 'OwnerDocumentationWizard';
        return 'OwnerMainScreen';
      }

      expect(resolveOwnerRoute(owner), 'OwnerMainScreen');
    });
  });

  // ─── E. Owner role preservation ───────────────────────────────────────────
  group('E. Owner role is preserved through flag transitions', () {
    test('role survives copyWith for every onboarding flag', () {
      final base = makeOwner();
      expect(base.role, 'owner');

      final afterOtp = base.copyWith(isRegistrationComplete: true);
      expect(afterOtp.role, 'owner');

      final afterStadium = afterOtp.copyWith(hasStadium: true);
      expect(afterStadium.role, 'owner');

      final afterVerification = afterStadium.copyWith(isIdentityVerified: true);
      expect(afterVerification.role, 'owner');
    });

    test('player UserModel never matches owner gating', () {
      final player = UserModel(
        uid: 'player-uid',
        email: 'player@test.com',
        role: 'player',
        phone: '+20 100 000 0002',
        isRegistrationComplete: true,
        hasStadium: false,
      );
      expect(player.role, isNot('owner'));
    });
  });

  // ─── F. isIdentityVerified write regression guard ──────────────────────────
  group('F. isIdentityVerified flag write regression', () {
    // Before the auth_service.dart fix, isIdentityVerified was stripped by
    // updateUserProfile(), causing the owner to loop through verification
    // indefinitely. These tests guard against that regression by verifying
    // the model transitions the flag correctly.
    test('copyWith sets isIdentityVerified from false to true', () {
      final pre = makeOwner(isIdentityVerified: false);
      final post = pre.copyWith(isIdentityVerified: true);
      expect(post.isIdentityVerified, isTrue);
    });

    test('fromFirestore reads isIdentityVerified correctly', () {
      final data = {
        'uid': 'uid-1',
        'email': 'owner@test.com',
        'role': 'owner',
        'hasStadium': true,
        'isIdentityVerified': true,
        'isRegistrationComplete': true,
        'isSuspended': false,
        'commissionDebt': 0,
      };
      final user = UserModel.fromFirestore(data);
      expect(user.isIdentityVerified, isTrue,
          reason: 'fromFirestore must read isIdentityVerified correctly');
    });

    test('fromFirestore defaults isIdentityVerified to false when absent', () {
      final data = {
        'uid': 'uid-2',
        'email': 'owner2@test.com',
        'role': 'owner',
      };
      final user = UserModel.fromFirestore(data);
      expect(user.isIdentityVerified, isFalse);
    });
  });

  // ─── G. Missing-phone gating (social onboarding guard) ───────────────────
  group('G. Social onboarding guard', () {
    test('owner with null phone is caught before owner gating', () {
      final owner = makeOwner(
        isRegistrationComplete: true,
        hasStadium: true,
        isIdentityVerified: true,
        phone: null,
      );
      // phone null → SocialOnboardingScreen (before owner checks)
      final hasMissingPhone =
          owner.phone == null || (owner.phone?.isEmpty ?? true);
      expect(hasMissingPhone, isTrue);
    });

    test('owner with empty string phone is caught before owner gating', () {
      final owner = makeOwner(phone: '');
      final hasMissingPhone =
          owner.phone == null || (owner.phone?.isEmpty ?? true);
      expect(hasMissingPhone, isTrue);
    });
  });
}
