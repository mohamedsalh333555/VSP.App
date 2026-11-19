import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification tap checks active account before routing', () {
    final source = File(
      'lib/features/player/screens/notifications_center_screen.dart',
    ).readAsStringSync();
    final tap = source.indexOf('Future<void> _onNotificationTap(BuildContext context)');
    final read = source.indexOf('markNotificationAsRead(', tap);
    final afterAwait = source.indexOf('context.read<AuthProvider>().currentUser?.id != userId', read);
    final navigate = source.indexOf('NotificationUiHelper.navigateToBooking(context, bookingId)', afterAwait);
    expect(tap, greaterThanOrEqualTo(0));
    expect(read, greaterThan(tap));
    expect(afterAwait, greaterThan(read));
    expect(navigate, greaterThan(afterAwait));
  });

  test('challenge action checks account before booking navigation', () {
    final source = File(
      'lib/features/player/screens/notifications_center_screen.dart',
    ).readAsStringSync();
    expect(source, contains('context.read<AuthProvider>().currentUser?.id == userId'));
    expect(source, contains('context.read<AuthProvider>().currentUser?.id != userId'));
  });
}
