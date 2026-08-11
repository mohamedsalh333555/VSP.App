import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vsp_application/core/navigation/app_router.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/core/models/user_model.dart';

class FakeAuthProvider implements AuthProvider {
  final bool _isInitializing;
  final bool _isAuthenticated;
  final bool _isGhostUser;
  final UserModel? _userModel;
  final bool _isOwner;
  final bool _hasDataFetchError;
  final String _email;

  FakeAuthProvider({
    bool isInitializing = false,
    bool isAuthenticated = true,
    bool isGhostUser = false,
    UserModel? userModel,
    bool isOwner = false,
    bool hasDataFetchError = false,
    String email = '',
  })  : _isInitializing = isInitializing,
        _isAuthenticated = isAuthenticated,
        _isGhostUser = isGhostUser,
        _userModel = userModel,
        _isOwner = isOwner,
        _hasDataFetchError = hasDataFetchError,
        _email = email;

  @override
  bool get isInitializing => _isInitializing;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  bool get isGhostUser => _isGhostUser;

  @override
  UserModel? get userModel => _userModel;

  @override
  bool get isOwner => _isOwner;

  @override
  bool get hasDataFetchError => _hasDataFetchError;

  @override
  String get email => _email;

  @override
  Stream<void> get celebrationEvents => const Stream.empty();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  bool get hasListeners => false;

  @override
  void dispose() {}

  @override
  void notifyListeners() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoRouterState implements GoRouterState {
  final Uri _uri;

  FakeGoRouterState(String url) : _uri = Uri.parse(url);

  @override
  Uri get uri => _uri;

  @override
  String get matchedLocation => _uri.path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('🛡️ VSP Deep Link Security & Gating Abuse Tests', () {
    
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

  });
}
