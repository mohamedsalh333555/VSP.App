import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/auth/services/password_recovery_session_guard.dart';

void main() {
  test('same original recovery session may proceed', () {
    expect(PasswordRecoverySessionGuard.isCurrent(
      recoveryUserId: 'recovering', currentUserId: () => 'recovering',
    ), isTrue);
  });
  test('new account after confirmation delay must not be logged out', () async {
    final pause = Completer<void>();
    var account = 'recovering';
    final next = pause.future.then((_) => PasswordRecoverySessionGuard.isCurrent(
      recoveryUserId: 'recovering', currentUserId: () => account,
    ));
    account = 'another-account';
    pause.complete();
    expect(await next, isFalse);
  });
  test('logged-out recovery session is rejected', () {
    expect(PasswordRecoverySessionGuard.isCurrent(
      recoveryUserId: 'recovering', currentUserId: () => null,
    ), isFalse);
  });
  test('disposed session provider is rejected', () {
    expect(PasswordRecoverySessionGuard.isCurrent(
      recoveryUserId: 'recovering',
      currentUserId: () => throw StateError('auth disposed'),
    ), isFalse);
  });
  test('empty identity never authorizes any session', () {
    expect(PasswordRecoverySessionGuard.isCurrent(
      recoveryUserId: '', currentUserId: () => '',
    ), isFalse);
  });
}
