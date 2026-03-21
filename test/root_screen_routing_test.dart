// auth_lifecycle_unit_test.dart
//
// Pure unit tests for the RootScreen routing logic.
// We avoid pumping RootScreen itself (which has Firebase-dependent initState).
// Instead, we extract and test the routing decision directly through a
// standalone helper that replicates _buildRootContent's logic.
//
// All 5 lifecycle gates are tested:
//   - Unauthenticated → WelcomeScreen
//   - Missing phone → SocialOnboardingScreen
//   - Registration incomplete → VerifyEmailScreen
//   - Owner, no stadium → FacilityOnboardingScreen
//   - Owner, has stadium, not identity-verified → OwnerDocumentationWizard

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';

// ─── Routing Decision Enum ──────────────────────────────────────────────────
// Mirrors the exact if-chain in RootScreen._buildRootContent().
enum RouteDecision {
  welcome,            // Not authenticated
  loading,            // Authenticated but no user data yet
  socialOnboarding,   // Missing phone number
  verifyEmail,        // isRegistrationComplete == false
  suspended,          // isSuspended == true
  facilityOnboarding, // Owner, hasStadium == false
  ownerDocumentation, // Owner, isIdentityVerified == false
  ownerDashboard,     // Fully onboarded owner
  playerHome,         // Fully registered player
}

/// Pure function that mirrors RootScreen._buildRootContent() logic exactly.
/// Returns the [RouteDecision] that the router would make.
RouteDecision resolveRoute({
  required bool isAuthenticated,
  required bool isMaintenanceMode,
  UserModel? user,
}) {
  if (isMaintenanceMode) return RouteDecision.welcome; // treated same as down

  if (!isAuthenticated) return RouteDecision.welcome;

  if (user == null) return RouteDecision.loading;

  // Missing phone → Social onboarding
  if (user.phone == null || user.phone!.isEmpty) {
    return RouteDecision.socialOnboarding;
  }

  // Registration not complete → Verify Email
  if (!user.isRegistrationComplete) {
    return RouteDecision.verifyEmail;
  }

  // Suspended
  if (user.isSuspended == true) return RouteDecision.suspended;

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

    // ────────────────────────────────────────────────────────────────────────
    test('Gate 1: Unauthenticated user → WelcomeScreen', () {
      final result = resolveRoute(
        isAuthenticated: false,
        isMaintenanceMode: false,
        user: null,
      );
      expect(result, RouteDecision.welcome);
    });

    // ────────────────────────────────────────────────────────────────────────
    test('Gate 2: Authenticated but user data still loading → SplashScreen', () {
      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: null, // data not yet fetched
      );
      expect(result, RouteDecision.loading);
    });

    // ────────────────────────────────────────────────────────────────────────
    test('Test 3: Social Login (Google/Apple) incomplete profile (no phone) → SocialOnboardingScreen', () {
      final user = UserModel(
        uid: '456',
        email: 'social@test.com',
        name: 'Social User',
        phone: '', // Empty phone = social login, not yet completed profile
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

      expect(result, RouteDecision.socialOnboarding,
          reason: 'User with empty phone must be redirected to SocialOnboardingScreen');
    });

    // ────────────────────────────────────────────────────────────────────────
    test('Test 1: Player email sign-up, registration incomplete → VerifyEmailScreen', () {
      final user = UserModel(
        uid: '123',
        email: 'player@test.com',
        name: 'Player One',
        phone: '0501234567',
        role: 'player',
        isRegistrationComplete: false,  // Not yet verified
        isEmailVerified: false,
        hasStadium: false,
        isIdentityVerified: false,
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.verifyEmail,
          reason: 'A player who has not completed registration must see VerifyEmailScreen');
    });

    // ────────────────────────────────────────────────────────────────────────
    test('Test 4a: Owner registration complete, NO stadium → FacilityOnboardingScreen', () {
      final user = UserModel(
        uid: '789',
        email: 'owner@test.com',
        name: 'Stadium Owner',
        phone: '0509876543',
        role: 'owner',
        isRegistrationComplete: true,
        isEmailVerified: true,
        hasStadium: false,           // ← no stadium yet
        isIdentityVerified: false,
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.facilityOnboarding,
          reason: 'Owner without a stadium must be routed to FacilityOnboardingScreen');
    });

    // ────────────────────────────────────────────────────────────────────────
    test('Test 4b: Owner has stadium, NOT identity-verified → OwnerDocumentationWizard', () {
      final user = UserModel(
        uid: '789',
        email: 'owner@test.com',
        name: 'Stadium Owner',
        phone: '0509876543',
        role: 'owner',
        isRegistrationComplete: true,
        isEmailVerified: true,
        hasStadium: true,            // ← has stadium
        isIdentityVerified: false,   // ← docs not submitted
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.ownerDocumentation,
          reason: 'Owner with stadium but unverified identity must see OwnerDocumentationWizard');
    });

    // ────────────────────────────────────────────────────────────────────────
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
        isIdentityVerified: true,   // ← fully verified
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.ownerDashboard);
    });

    // ────────────────────────────────────────────────────────────────────────
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

      expect(result, RouteDecision.playerHome,
          reason: 'A fully registered player must go directly to PlayerHomeScreen');
    });

    // ────────────────────────────────────────────────────────────────────────
    test('Suspended user → Suspended (regardless of role)', () {
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
        isSuspended: true,
      );

      final result = resolveRoute(
        isAuthenticated: true,
        isMaintenanceMode: false,
        user: user,
      );

      expect(result, RouteDecision.suspended,
          reason: 'A suspended account must be blocked regardless of other flags');
    });

  });
}
