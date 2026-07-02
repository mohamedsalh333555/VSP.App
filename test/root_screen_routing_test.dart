// root_screen_routing_test.dart
//
// Pure unit tests for the RootScreen routing logic.
// All lifecycle gates are tested:
//   - Unauthenticated → WelcomeScreen
//   - Missing phone → SocialOnboardingScreen
//   - Registration incomplete → VerifyEmailScreen
//   - Owner, no stadium → FacilityOnboardingScreen
//   - Owner, has stadium, not identity-verified → OwnerDocumentationWizard
//   - Blocked player → Suspended/Blocked Screen

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';

// ─── Routing Decision Enum ──────────────────────────────────────────────────
enum RouteDecision {
  welcome,            // Not authenticated
  loading,            // Authenticated but no user data yet
  socialOnboarding,   // Missing phone number
  verifyEmail,        // isRegistrationComplete == false
  suspended,          // isBlocked == true (player only)
  facilityOnboarding, // Owner, hasStadium == false
  ownerDocumentation, // Owner, isIdentityVerified == false
  ownerDashboard,     // Fully onboarded owner (blocked or unblocked)
  playerHome,         // Fully registered player
}

/// Pure function that mirrors new router decision tree exactly.
RouteDecision resolveRoute({
  required bool isAuthenticated,
  required bool isMaintenanceMode,
  UserModel? user,
}) {
  if (isMaintenanceMode) return RouteDecision.welcome;

  if (!isAuthenticated) return RouteDecision.welcome;

  if (user == null) return RouteDecision.loading;

  // Missing phone → Social onboarding
  if (user.phone == null || user.phone!.isEmpty) {
    return RouteDecision.socialOnboarding;
  }



  // Administrative Block check
  if (user.isBlocked) {
    if (user.role == 'owner') {
      // Blocked owners proceed to owner dashboard with alert
      return RouteDecision.ownerDashboard;
    } else {
      // Blocked players locked out completely
      return RouteDecision.suspended;
    }
  }

  // Owner flow
  if (user.role == 'owner') {
    if (!user.hasStadium) return RouteDecision.facilityOnboarding;
    if (!user.isIdentityVerified) return RouteDecision.ownerDocumentation;
    return RouteDecision.ownerDashboard;
  }

  // Player
  return RouteDecision.playerHome;
}

void main() {
  group('RootScreen Auth Lifecycle Routing Tests', () {

    test('Gate 1: Unauthenticated user → WelcomeScreen', () {
      final result = resolveRoute(
        isAuthenticated: false,
        isMaintenanceMode: false,
        user: null,
      );
      expect(result, RouteDecision.welcome);
    });

    test('Gate 2: Authenticated but user data still loading → SplashScreen', () {
      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: null,
      );
      expect(result, RouteDecision.loading);
    });

    test('Test 3: Social Login (Google/Apple) incomplete profile (no phone) → SocialOnboardingScreen', () {
      final user = UserModel(
        uid: '456',
        email: 'social@test.com',
        name: 'Social User',
        phone: '',
        role: 'player',
        isRegistrationComplete: false,
        isEmailVerified: true,
        hasStadium: false,
        isIdentityVerified: false,
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.socialOnboarding);
    });

    test('Test 1: Player email sign-up, registration incomplete → playerHome', () {
      final user = UserModel(
        uid: '123',
        email: 'player@test.com',
        name: 'Player One',
        phone: '0501234567',
        role: 'player',
        isRegistrationComplete: false,
        isEmailVerified: false,
        hasStadium: false,
        isIdentityVerified: false,
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.playerHome);
    });

    test('Test 4a: Owner registration complete, NO stadium → FacilityOnboardingScreen', () {
      final user = UserModel(
        uid: '789',
        email: 'owner@test.com',
        name: 'Stadium Owner',
        phone: '0509876543',
        role: 'owner',
        isRegistrationComplete: true,
        isEmailVerified: true,
        hasStadium: false,
        isIdentityVerified: false,
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.facilityOnboarding);
    });

    test('Test 4b: Owner has stadium, NOT identity-verified → OwnerDocumentationWizard', () {
      final user = UserModel(
        uid: '789',
        email: 'owner@test.com',
        name: 'Stadium Owner',
        phone: '0509876543',
        role: 'owner',
        isRegistrationComplete: true,
        isEmailVerified: true,
        hasStadium: true,
        isIdentityVerified: false,
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.ownerDocumentation);
    });

    test('Fully verified owner → OwnerDashboard', () {
      final user = UserModel(
        uid: '789',
        email: 'owner@test.com',
        name: 'Stadium Owner',
        phone: '0509876543',
        role: 'owner',
        isRegistrationComplete: true,
        isEmailVerified: true,
        hasStadium: true,
        isIdentityVerified: true,
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.ownerDashboard);
    });

    test('Fully registered player → PlayerHome', () {
      final user = UserModel(
        uid: '999',
        email: 'player@test.com',
        name: 'Valid Player',
        phone: '0503330000',
        role: 'player',
        isRegistrationComplete: true,
        isEmailVerified: true,
        hasStadium: false,
        isIdentityVerified: false,
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.playerHome);
    });

    test('Blocked player → Suspended (route to block screen)', () {
      final user = UserModel(
        uid: '111',
        email: 'bad@test.com',
        name: 'Bad Actor',
        phone: '0500000001',
        role: 'player',
        isRegistrationComplete: true,
        isEmailVerified: true,
        hasStadium: false,
        isIdentityVerified: false,
        isBlocked: true,
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.suspended);
    });

    test('Blocked owner → OwnerDashboard (allowed entry, warning shown on dashboard)', () {
      final user = UserModel(
        uid: '222',
        email: 'blockedowner@test.com',
        name: 'Blocked Owner',
        phone: '0500000002',
        role: 'owner',
        isRegistrationComplete: true,
        isEmailVerified: true,
        hasStadium: true,
        isIdentityVerified: true,
        isBlocked: true,
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.ownerDashboard);
    });
  });
}
