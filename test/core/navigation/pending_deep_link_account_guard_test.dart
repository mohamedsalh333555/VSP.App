import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/navigation/pending_deep_link_account_guard.dart';

void main() {
  bool canReplay({
    String? expected = 'player-A',
    String? current = 'player-A',
    String? profile = 'player-A',
    bool authenticated = true,
    bool complete = true,
  }) => PendingDeepLinkAccountGuard.canReplay(
    requestedForUserId: expected,
    currentUserId: current,
    profileUserId: profile,
    isAuthenticated: authenticated,
    isRegistrationComplete: complete,
  );

  test('same signed-in account with completed profile may replay', () {
    expect(canReplay(), isTrue);
  });

  test('sign-out and unauthenticated session invalidate the pending route', () {
    expect(canReplay(authenticated: false), isFalse);
    expect(canReplay(current: null), isFalse);
    expect(canReplay(profile: null), isFalse);
  });

  test('another account cannot inherit the previous account pending navigation', () {
    expect(canReplay(current: 'player-B'), isFalse);
    expect(canReplay(profile: 'player-B'), isFalse);
    expect(canReplay(current: 'player-B', profile: 'player-B'), isFalse);
    expect(canReplay(expected: ''), isFalse);
    expect(canReplay(expected: null), isFalse);
  });

  test('incomplete and unhydrated onboarding profiles cannot replay', () {
    expect(canReplay(complete: false), isFalse);
    expect(canReplay(profile: null), isFalse);
  });

  test('two replay consumers cannot navigate simultaneously', () {
    PendingDeepLinkAccountGuard.release();
    try {
      expect(PendingDeepLinkAccountGuard.tryAcquire(), isTrue);
      expect(PendingDeepLinkAccountGuard.tryAcquire(), isFalse);
    } finally {
      PendingDeepLinkAccountGuard.release();
    }
    expect(PendingDeepLinkAccountGuard.tryAcquire(), isTrue);
    PendingDeepLinkAccountGuard.release();
  });

  test('RootScreen and app startup both recheck account across async work', () {
    final root = File('lib/core/navigation/root_screen.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    for (final source in [root, main]) {
      expect(source, contains('PendingDeepLinkAccountGuard.canReplay('));
      expect(source, contains('PendingDeepLinkAccountGuard.tryAcquire()'));
      expect(source, contains('PendingDeepLinkAccountGuard.release()'));
      expect(source, contains("prefs.getString('pending_deep_link')"));
      expect(source, contains("prefs.remove('pending_deep_link')"));
      expect(source, contains('if (parsed == null || !sameVerifiedAccount()'));

      expect(source, contains('profileUserId: current.userModel?.uid,'));
    }
    expect(root, contains('final expectedUserId = initialAuth.currentUser?.id;'));
    expect(main, contains('final expectedUserId = auth.currentUser?.id;'));
  });
}
