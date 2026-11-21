import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/core/services/notification_service.dart')
      .readAsStringSync();

  test('foreground local notification checks recipient before presenting', () {
    final from = source.indexOf('_foregroundMessageSubscription ??=');
    final to = source.indexOf('_openedMessageSubscription ??=', from);
    final block = source.substring(from, to);
    final recipient = block.indexOf('isRecipientCurrentUser(');
    final pref = block.indexOf('await _shouldShowNotification(');
    final accountAfterAsync = block.indexOf('auth.currentUser?.id != userId', pref);
    final nativeDisplay = block.indexOf('await _showLocalNotification(', accountAfterAsync);
    expect(recipient, greaterThan(0));
    expect(pref, greaterThan(recipient));
    expect(accountAfterAsync, greaterThan(pref));
    expect(nativeDisplay, greaterThan(accountAfterAsync));
  });

  test('realtime notification checks captured account, row owner and preferences', () {
    final from = source.indexOf('void listenToRealtimeNotifications(');
    final to = source.indexOf('void stopRealtimeNotificationsListener(', from);
    final block = source.substring(from, to);
    expect(block, contains("record['user_id']?.toString() != userId"));
    expect(block, contains('currentUser?.id != userId'));
    expect(block, contains('await _shouldShowNotification('));
    expect(block, contains("'recipientUserId': userId"));
  });

  test('local pushes use scoped preferences, not device-global settings', () {
    expect(source, contains('shouldShowNotificationForUser('));
    expect(source, contains("scopedPrefKey(userId, 'notif_general')"));
    expect(source, contains("scopedPrefKey(userId, 'notif_match_reminders')"));
    expect(source, contains("scopedPrefKey(userId, 'notif_cash_bookings')"));
    expect(source, isNot(contains("prefs.getBool('notif_general')")));
    expect(source, isNot(contains("prefs.containsKey('notif_owner_new_bookings')")));
  });

  test('notification clicks check account and reject unsafe route segments', () {
    final from = source.indexOf('void _handleNotificationClick(');
    final to = source.indexOf('Future<void> _showLocalNotification(', from);
    final block = source.substring(from, to);
    expect(block, contains('isRecipientCurrentUser(data, userId)'));
    expect(block, contains('resolveDeepLinkRoute(data)'));
    expect(block, contains("!RegExp(r'[^a-zA-Z0-9_-]').hasMatch(tournamentId)"));
    expect(block, isNot(contains("VSPLogger.i('Handling notification click:")));
  });
}
