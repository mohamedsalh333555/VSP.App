import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/navigation/app_router.dart';
import 'helpers/router_auth_fakes.dart';

UserModel profile({
  required String role,
  bool blocked = false,
  bool verified = true,
  bool hasStadium = false,
  bool completedOwnerOnboarding = false,
  String phone = '01012345678',
}) => UserModel(
  uid: 'fixture-$role',
  email: 'fixture@example.invalid',
  role: role,
  phone: phone,
  isBlocked: blocked,
  isEmailVerified: verified,
  isRegistrationComplete: true,
  hasStadium: hasStadium,
  isOnboardingConfirmed: completedOwnerOnboarding,
);

String? redirect(String path, FakeAuthProvider auth) =>
    AppRouter.redirectLogic(
      DummyBuildContext(), FakeGoRouterState(path), auth,
    );

void main() {
  group('Root route gates — production AppRouter, not duplicated policy', () {
    test('signed out sessions cannot access owner and player content', () {
      final auth = FakeAuthProvider(isAuthenticated: false);
      for (final path in [
        '/', '/owner', '/owner-ledger', '/match/booking-id',
        '/team/team-id', '/notifications',
      ]) {
        expect(redirect(path, auth), '/welcome', reason: path);
      }
      expect(redirect('/login', auth), isNull);
    });

    test('initialization and incomplete profile are sent to splash', () {
      final initializing = FakeAuthProvider(isInitializing: true);
      expect(redirect('/owner', initializing), '/splash');
      expect(redirect('/splash', initializing), isNull);
      final loading = FakeAuthProvider(isLoading: true);
      expect(redirect('/owner', loading), '/splash');
    });

    test('new OAuth accounts must finish onboarding for their role', () {
      for (final role in ['owner', 'player']) {
        final auth = FakeAuthProvider(isGhostUser: true, userType: role);
        final destination =
            role == 'owner' ? '/onboarding-owner' : '/onboarding-player';
        expect(redirect('/owner', auth), destination);
        expect(redirect(destination, auth), isNull);
      }
    });

    test('missing phone goes to the correct onboarding surface', () {
      final player = FakeAuthProvider(userModel: profile(role: 'player', phone: ''));
      final owner = FakeAuthProvider(
        isOwner: true, userModel: profile(role: 'owner', phone: ''),
      );
      expect(redirect('/notifications', player), '/onboarding-player');
      expect(redirect('/owner', owner), '/onboarding-owner');
    });

    test('unverified email is blocked before dashboards', () {
      final player = FakeAuthProvider(
        userModel: profile(role: 'player', verified: false),
      );
      final owner = FakeAuthProvider(
        isOwner: true, userModel: profile(role: 'owner', verified: false),
      );
      expect(redirect('/player', player), '/verify-email');
      expect(redirect('/owner', owner), '/verify-email');
      expect(redirect('/verify-email', player), isNull);
    });

    test('suspension blocks owners and players equally', () {
      for (final role in ['owner', 'player']) {
        final auth = FakeAuthProvider(
          isOwner: role == 'owner',
          userModel: profile(
            role: role, blocked: true, verified: true,
            hasStadium: role == 'owner',
            completedOwnerOnboarding: role == 'owner',
          ),
        );
        for (final path in ['/owner', '/player', '/notifications']) {
          expect(redirect(path, auth), '/suspended',
              reason: 'Suspended $role must never access $path');
        }
        expect(redirect('/suspended', auth), isNull);
      }
    });

    test('owner stadium onboarding must complete before dashboard', () {
      final noStadium = FakeAuthProvider(
        isOwner: true, userModel: profile(role: 'owner'),
      );
      expect(redirect('/owner', noStadium), '/facility-onboarding');
      final unfinished = FakeAuthProvider(
        isOwner: true,
        userModel: profile(role: 'owner', hasStadium: true),
      );
      expect(redirect('/owner', unfinished), '/facility-onboarding');
      final complete = FakeAuthProvider(
        isOwner: true,
        userModel: profile(
          role: 'owner', hasStadium: true, completedOwnerOnboarding: true,
        ),
      );
      // Completed owners enter the dashboard through RootScreen at '/'.
      expect(redirect('/owner', complete), '/');
      expect(redirect('/documentation', complete), isNull);
      expect(redirect('/player', complete), '/owner');
    });

    test('signed-in players cannot open owner billing', () {
      final auth = FakeAuthProvider(userModel: profile(role: 'player'));
      expect(redirect('/owner-ledger', auth), '/');
      expect(redirect('/subscription-plans', auth), '/');
      expect(redirect('/notifications', auth), isNull);
    });
  });
}
