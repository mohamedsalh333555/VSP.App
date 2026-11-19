import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification invite navigation is after active account protection', () {
    final source = File(
      'lib/features/player/screens/notifications_center_screen.dart'
    ).readAsStringSync();
    final activeAccount = source.indexOf(
      'context.read<AuthProvider>().currentUser?.id != userId',
      source.indexOf('Future<void> _onNotificationTap('));
    final routeGuard = source.indexOf(
      'TeamInvitationNotificationRoute.opensCurrentPlayerInbox',
      activeAccount);
    final route = source.indexOf(
      'TeamInvitationsSheet(userId: userId)', routeGuard);
    expect(activeAccount, greaterThan(0));
    expect(routeGuard, greaterThan(activeAccount));
    expect(route, greaterThan(routeGuard));
    expect(source.substring(routeGuard,route), contains('isScrollControlled: true'));
  });
}
