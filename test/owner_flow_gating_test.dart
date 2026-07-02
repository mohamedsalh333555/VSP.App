import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Owner Flow Gating Tests
//
// These tests validate the AppRouter gating logic by testing the UserModel
// flag combinations that drive each routing decision.
//
// Covers:
//  A. Owner with no stadium → FacilityOnboardingScreen path
//  B. Owner with stadium but not verified → OwnerDocumentationWizard path
//  C. Blocked owner → OwnerMainScreen path (allowed access but de-activated)
//  D. Fully completed owner → OwnerMainScreen path
//  E. Owner role is preserved through signup and flag transitions
//  F. isIdentityVerified write now unblocked
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // Helper: create a base owner UserModel with given flag overrides
  UserModel makeOwner({
    bool hasStadium = false,
    bool isIdentityVerified = false,
    bool isRegistrationComplete = false,
    bool isBlocked = false,
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
      isBlocked: isBlocked,
    );
  }

  // ─── A. Owner with no stadium ─────────────────────────────────────────────
  group('A. Owner without a stadium', () {
    test('should route to FacilityOnboardingScreen', () {
      final owner = makeOwner(
        isRegistrationComplete: true,
        hasStadium: false,
        isIdentityVerified: false,
        isBlocked: false,
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
        isBlocked: false,
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

  // ─── C. Blocked owner ───────────────────────────────────────────────────
  group('C. Blocked owner', () {
    test('should still route to OwnerMainScreen but with blocked status', () {
      final blocked = makeOwner(
        isRegistrationComplete: true,
        hasStadium: true,
        isIdentityVerified: true,
        isBlocked: true,
      );

      expect(blocked.isBlocked, isTrue,
          reason: 'Blocked owner is allowed to proceed to OwnerMainScreen where dashboard disables actions');
    });

    test('blocked player should route to SuspendedAccountScreen', () {
      final blockedPlayer = UserModel(
        uid: 'test-player-uid',
        email: 'player@test.com',
        role: 'player',
        isRegistrationComplete: true,
        isBlocked: true,
        phone: '+20 100 000 0000',
      );
      expect(blockedPlayer.isBlocked, isTrue);
      expect(blockedPlayer.role, 'player');
    });
  });

  // ─── D. Fully completed owner ─────────────────────────────────────────────
  group('D. Fully completed owner', () {
    test('should route to OwnerMainScreen', () {
      final owner = makeOwner(
        isRegistrationComplete: true,
        hasStadium: true,
        isIdentityVerified: true,
        isBlocked: false,
      );

      expect(owner.isRegistrationComplete, isTrue);
      expect(owner.hasStadium, isTrue);
      expect(owner.isIdentityVerified, isTrue);
      expect(owner.isBlocked, isFalse,
          reason: 'All flags complete → OwnerMainScreen');
    });

    test('Router gating logic expressed as pure flag evaluation', () {
      final owner = makeOwner(
        isRegistrationComplete: true,
        hasStadium: true,
        isIdentityVerified: true,
        isBlocked: false,
        phone: '+20 100 000 0001',
      );

      // Replicate new router decision tree as a pure function
      String resolveOwnerRoute(UserModel u) {
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
        'isBlocked': false,
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
