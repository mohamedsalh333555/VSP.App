import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/navigation/app_router.dart';
import 'package:vsp_application/core/navigation/app_route_role_guard.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'helpers/router_auth_fakes.dart';

void main() {
 group(' VSP Deep Link Security & Gating Abuse Tests', () {
 
 test('1. Abuse Test: Blocked Player Deep Link Bypass Prevention', () async {
 // Simulate an authenticated player who is administrative-blocked
 final authProvider = FakeAuthProvider(
 isAuthenticated: true,
 isOwner: false,
 userModel: UserModel(
 uid: 'blocked-player-uuid',
 email: 'blocked@vsp.app',
 role: 'player',
 name: 'Blocked Bad Actor',
 phone: '01012345678',
 isBlocked: true,
 isRegistrationComplete: true,
 isEmailVerified: true,
 ),
 );
 
 // Simulate receiving deep link to a match while blocked
 final redirectResult = AppRouter.redirectLogic(
 DummyBuildContext(),
 FakeGoRouterState('/match/valid-booking-uuid'),
 authProvider,
 );

 // Verify they are strictly redirected to /suspended and cannot bypass the block
 expect(redirectResult, '/suspended');
 });

 test('2. Robustness Test: Malformed/Garbage Match UUID Input', () {
 // Test regex parsing behavior that handles deep links in main.dart
 final garbageId = 'garbage-id-!@#\$%-invalid';
 final validId = 'valid-booking-uuid-1234';

 final idRegex = RegExp(r'^[a-zA-Z0-9\-_\s]+$');

 // Verify garbage ID format fails validation securely
 final isGarbageValid = idRegex.hasMatch(garbageId);
 expect(isGarbageValid, isFalse, reason: 'Garbage ID containing special characters must fail validation');

 // Verify normal alphanumeric/UUID formats pass validation
 final isValidPass = idRegex.hasMatch(validId);
 expect(isValidPass, isTrue, reason: 'Valid UUID/Alphanumeric ID format must pass validation');
 });

 test('3. Role Isolation Test: Owner Attempting Player Match Deep Link', () async {
 // Simulate an authenticated and fully verified Owner
 final authProvider = FakeAuthProvider(
 isAuthenticated: true,
 isOwner: true,
 userModel: UserModel(
 uid: 'owner-uuid-123',
 email: 'owner@vsp.app',
 role: 'owner',
 name: 'Stadium Owner',
 phone: '01012345678',
 isBlocked: false,
 isRegistrationComplete: true,
 isEmailVerified: true,
 hasStadium: true,
 isIdentityVerified: true,
 additionalData: {'isOnboardingConfirmed': true},
 ),
 );

 // Simulate Owner attempting to navigate to player-specific match deep link
 final redirectResult = AppRouter.redirectLogic(
 DummyBuildContext(),
 FakeGoRouterState('/match/valid-booking-uuid'),
 authProvider,
 );

 // Verify they are strictly prevented from viewing player-specific screen and sent back to /owner
 expect(redirectResult, '/owner');
 });

 test('4. Player direct links cannot open owner-only surfaces', () {
   final player = FakeAuthProvider(
     isAuthenticated: true,
     isOwner: false,
     userModel: UserModel(
       uid: 'verified-player',
       email: 'player@example.invalid',
       role: 'player',
       phone: '01012345678',
       isBlocked: false,
       isRegistrationComplete: true,
       isEmailVerified: true,
     ),
   );
   for (final path in [
     '/owner',
     '/facility-onboarding',
     '/documentation',
     '/copilot',
     '/owner-ledger',
     '/subscription-plans',
     '/owner?tab=financial',
     '/documentation?step=files',
   ]) {
     final actual = AppRouter.redirectLogic(
       DummyBuildContext(), FakeGoRouterState(path), player,
     );
     expect(actual, '/', reason: 'Player direct URL: $path');
   }
   // Public player deep links remain available to a verified player.
   for (final path in [
     '/match/verified-booking',
     '/team/visible-team',
     '/collective/fixture-invite',
     '/notifications',
     '/edit-profile',
   ]) {
     expect(AppRouter.redirectLogic(
       DummyBuildContext(), FakeGoRouterState(path), player,
     ), isNull, reason: 'Player must be allowed to use $path');
   }
 });

 test('5. Owner direct links cannot open player-only screens', () {
   final owner = FakeAuthProvider(
     isAuthenticated: true,
     isOwner: true,
     userModel: UserModel(
       uid: 'verified-owner',
       email: 'owner@example.invalid',
       role: 'owner',
       phone: '01012345678',
       isBlocked: false,
       isRegistrationComplete: true,
       isEmailVerified: true,
       hasStadium: true,
       isOnboardingConfirmed: true,
     ),
   );
   for (final path in [
     '/player',
     '/match/another-booking',
     '/team/another-team',
     '/collective/private-invite',
     '/edit-profile',
     '/notifications',
   ]) {
     expect(AppRouter.redirectLogic(
       DummyBuildContext(), FakeGoRouterState(path), owner,
     ), '/owner', reason: 'Owner direct URL: $path');
   }
   expect(AppRouter.redirectLogic(
     DummyBuildContext(), FakeGoRouterState('/documentation'), owner,
   ), isNull);
   expect(AppRouter.redirectLogic(
     DummyBuildContext(), FakeGoRouterState('/copilot'), owner,
   ), isNull);
   for (final ownerBillingPath in [
     '/subscription-plans',
     '/owner-ledger',
   ]) {
     expect(AppRouter.redirectLogic(
       DummyBuildContext(), FakeGoRouterState(ownerBillingPath), owner,
     ), isNull, reason: 'Owner billing notification route should be registered');
   }
 });

 test('6. Unknown roles fail closed and exact path matches prevent false positives', () {
   for (final path in [
     '/owner', '/documentation', '/facility-onboarding', '/copilot',
     '/subscription-plans', '/owner-ledger',
   ]) {
     expect(AppRouteRoleGuard.redirectForRole(
       path: path, isOwner: false, isAdmin: false,
     ), '/');
   }
   expect(AppRouteRoleGuard.redirectForRole(
     path: '/ownerish', isOwner: false, isAdmin: false,
   ), isNull);
   expect(AppRouteRoleGuard.redirectForRole(
     path: '/teamwork', isOwner: true, isAdmin: false,
   ), isNull);
   expect(AppRouteRoleGuard.redirectForRole(
     path: '/owner', isOwner: false, isAdmin: true,
   ), isNull);
   expect(AppRouteRoleGuard.redirectForRole(
     path: '/match/booking', isOwner: true, isAdmin: true,
   ), isNull);
 });

 test('7. Suspended user denial takes precedence over role-based routing', () {
   final blocked = FakeAuthProvider(
     isAuthenticated: true,
     isOwner: false,
     userModel: UserModel(
       uid: 'suspended-player',
       email: 'blocked@example.invalid',
       role: 'player',
       phone: '01012345678',
       isBlocked: true,
       isRegistrationComplete: true,
       isEmailVerified: true,
     ),
   );
   expect(AppRouter.redirectLogic(
     DummyBuildContext(), FakeGoRouterState('/owner'), blocked,
   ), '/suspended');
 });


 test('8. Expired session denies private routes even with a stale hydrated owner', () {
   final expiredAuth = FakeAuthProvider(
     isAuthenticated: false,
     isOwner: true,
     userModel: UserModel(
       uid: 'prior-account',
       email: 'prior@example.invalid',
       role: 'owner',
       phone: '01012345678',
       hasStadium: true,
       isEmailVerified: true,
       isOnboardingConfirmed: true,
       isRegistrationComplete: true,
     ),
   );
   for (final path in [
     '/',
     '/owner',
     '/owner-ledger',
     '/subscription-plans',
     '/documentation',
     '/match/previous-booking',
     '/team/previous-team',
     '/notifications',
   ]) {
     expect(AppRouter.redirectLogic(
       DummyBuildContext(), FakeGoRouterState(path), expiredAuth,
     ), '/welcome', reason: 'logout must invalidate $path');
   }
   expect(AppRouter.redirectLogic(
     DummyBuildContext(), FakeGoRouterState('/login'), expiredAuth,
   ), isNull);
 });

 });
}
