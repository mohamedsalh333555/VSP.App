import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/navigation/app_router.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  final bool _isAuthenticated;
  final bool _isOwner;
  final UserModel? _userModel;

  _FakeAuthProvider({
    required bool isAuthenticated,
    required bool isOwner,
    required UserModel? userModel,
  })  : _isAuthenticated = isAuthenticated,
        _isOwner = isOwner,
        _userModel = userModel;

  @override
  bool get isInitializing => false;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  bool get isGhostUser => false;

  @override
  bool get isOwner => _isOwner;

  @override
  bool get isAdmin => false;

  @override
  bool get hasDataFetchError => false;

  @override
  UserModel? get userModel => _userModel;

  @override
  String? get userType => _isOwner ? 'owner' : 'player';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoRouterState implements GoRouterState {
  final Uri _uri;

  _FakeGoRouterState(String url) : _uri = Uri.parse(url);

  @override
  Uri get uri => _uri;

  @override
  String get matchedLocation => _uri.path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Owner Facility Onboarding & Skip Routing Tests', () {
    test('Owner without stadium and unconfirmed onboarding is redirected to /facility-onboarding', () {
      final auth = _FakeAuthProvider(
        isAuthenticated: true,
        isOwner: true,
        userModel: UserModel(
          uid: 'owner_1',
          email: 'owner1@vsp.app',
          phone: '01012345678',
          role: 'owner',
          isEmailVerified: true,
          hasStadium: false,
          isOnboardingConfirmed: false,
        ),
      );

      final redirect = AppRouter.redirectLogic(
        _DummyBuildContext(),
        _FakeGoRouterState('/owner'),
        auth,
      );

      expect(redirect, equals('/facility-onboarding'));
    });

    test('Owner who skips stadium addition (isOnboardingConfirmed == true, hasStadium == false) can access /owner', () {
      final auth = _FakeAuthProvider(
        isAuthenticated: true,
        isOwner: true,
        userModel: UserModel(
          uid: 'owner_skipped',
          email: 'owner_skipped@vsp.app',
          phone: '01012345678',
          role: 'owner',
          isEmailVerified: true,
          hasStadium: false,
          isOnboardingConfirmed: true,
        ),
      );

      final redirect = AppRouter.redirectLogic(
        _DummyBuildContext(),
        _FakeGoRouterState('/owner'),
        auth,
      );

      // In AppRouter, access to /owner for valid authenticated owners routes to '/' which renders OwnerMainScreen
      expect(redirect, equals('/'));
    });

    test('Owner with stadium (hasStadium == true) can access /owner dashboard', () {
      final auth = _FakeAuthProvider(
        isAuthenticated: true,
        isOwner: true,
        userModel: UserModel(
          uid: 'owner_with_stadium',
          email: 'owner_stadium@vsp.app',
          phone: '01012345678',
          role: 'owner',
          isEmailVerified: true,
          hasStadium: true,
          isOnboardingConfirmed: true,
        ),
      );

      final redirect = AppRouter.redirectLogic(
        _DummyBuildContext(),
        _FakeGoRouterState('/owner'),
        auth,
      );

      expect(redirect, equals('/'));
    });
  });

  // ── اختبارات آلة الحالات الجديدة ─────────────────────────────────────────
  group('Owner Verification State Machine & Trial Freeze Tests', () {
    test('pending owner: isVerifiedForOperations returns false', () {
      final user = UserModel(
        uid: 'pending_owner',
        email: 'pending@vsp.app',
        role: 'owner',
        isEmailVerified: true,
        verificationStatus: 'pending',
        isIdentityVerified: false,
      );
      expect(user.isVerifiedForOperations, isFalse);
    });

    test('rejected owner: isVerifiedForOperations returns false', () {
      final user = UserModel(
        uid: 'rejected_owner',
        email: 'rejected@vsp.app',
        role: 'owner',
        isEmailVerified: true,
        verificationStatus: 'rejected',
        isIdentityVerified: false,
      );
      expect(user.isVerifiedForOperations, isFalse);
    });

    test('approved owner: isVerifiedForOperations returns true', () {
      final user = UserModel(
        uid: 'approved_owner',
        email: 'approved@vsp.app',
        role: 'owner',
        isEmailVerified: true,
        verificationStatus: 'approved',
        isIdentityVerified: true,
      );
      expect(user.isVerifiedForOperations, isTrue);
    });

    test('pending owner: isInActiveTrial returns false (trial is frozen until approval)', () {
      final user = UserModel(
        uid: 'trial_pending',
        email: 'trial_pending@vsp.app',
        role: 'owner',
        isEmailVerified: true,
        verificationStatus: 'pending',
        isIdentityVerified: false,
        subscriptionPlan: 'free_trial',
        // trialEndsAt في المستقبل — لكن يجب ألا يُحتسب
        trialEndsAt: DateTime.now().add(const Duration(days: 55)),
      );
      // الفترة المجانية مجمدة لأن المالك لم يُعتمد بعد
      expect(user.isInActiveTrial, isFalse);
    });

    test('approved owner with active trial: isInActiveTrial returns true', () {
      final user = UserModel(
        uid: 'trial_approved',
        email: 'trial_approved@vsp.app',
        role: 'owner',
        isEmailVerified: true,
        verificationStatus: 'approved',
        isIdentityVerified: true,
        subscriptionPlan: 'free_trial',
        trialEndsAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(user.isInActiveTrial, isTrue);
    });
  });
}
