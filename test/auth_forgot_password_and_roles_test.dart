import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/navigation/app_router.dart';
import 'helpers/router_auth_fakes.dart';

FakeAuthProvider session({
  required String role,
  bool blocked = false,
  bool verified = true,
}) => FakeAuthProvider(
  isOwner: role == 'owner',
  userModel: UserModel(
    uid: 'role-$role',
    email: '$role@example.invalid',
    name: 'Test account',
    role: role,
    phone: '01012345678',
    isEmailVerified: verified,
    isRegistrationComplete: true,
    isBlocked: blocked,
    hasStadium: role == 'owner',
    isOnboardingConfirmed: role == 'owner',
  ),
);

String? redirect(String path, FakeAuthProvider auth) =>
    AppRouter.redirectLogic(
      DummyBuildContext(), FakeGoRouterState(path), auth,
    );

void main() {
  group('Auth role regression — production route logic', () {
    test('verified player can open player screens but not owner screens', () {
      final auth = session(role: 'player');
      expect(redirect('/match/match-id', auth), isNull);
      expect(redirect('/team/team-id', auth), isNull);
      expect(redirect('/owner', auth), '/');
      expect(redirect('/owner-ledger', auth), '/');
    });

    test('verified owner can open dashboard but not player screens', () {
      final auth = session(role: 'owner');
      expect(redirect('/owner', auth), isNull);
      expect(redirect('/subscription-plans', auth), isNull);
      expect(redirect('/match/match-id', auth), '/owner');
    });

    test('administrative block denies both player and owner route access', () {
      for (final role in ['player', 'owner']) {
        final auth = session(role: role, blocked: true);
        expect(redirect(role == 'owner' ? '/owner' : '/player', auth),
            '/suspended', reason: role);
        expect(redirect('/suspended', auth), isNull);
      }
    });

    test('email verification overrides normal role routing', () {
      for (final role in ['player', 'owner']) {
        final auth = session(role: role, verified: false);
        expect(redirect(role == 'owner' ? '/owner' : '/player', auth),
            '/verify-email', reason: role);
      }
    });

    test('password recovery screen remains available to signed-out users', () {
      final signedOut = FakeAuthProvider(isAuthenticated: false);
      expect(redirect('/set-new-password', signedOut), isNull);
      expect(redirect('/owner', signedOut), '/welcome');
      // Supabase verifies the recovery token separately. This routing test
      // must not be mistaken for a real password-recovery token E2E test.
    });
  });
}
