import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sign-out removes user-bound token before JWT is revoked', () {
    final signout = File('lib/core/providers/auth/auth_sign_out_handler.dart')
        .readAsStringSync();
    final unlink = signout.indexOf('unregisterCurrentDeviceForUser(user.id)');
    final revoke = signout.indexOf('await authService.signOut()');
    expect(unlink, greaterThan(0));
    expect(revoke, greaterThan(unlink));
  });

  test('token deletion never crosses account boundary and invalidates FCM', () {
    final source = File('lib/core/services/notification_service.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<void> unregisterCurrentDeviceForUser(');
    final stop = source.indexOf('Future<void> _registerTokenForUser(', start);
    final method = source.substring(start, stop);
    expect(start, greaterThan(0));
    expect(method, contains(".delete().eq('user_id', userId).eq('token', token)"));
    expect(method, contains('await _firebaseMessaging.deleteToken()'));
    expect(method, contains('Supabase.instance.client.auth.currentUser?.id != userId'));
  });
}
