import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/player/screens/profile_subscreens/notifications_screen.dart',
  ).readAsStringSync();

  test('preferences are scoped by current user, never global legacy keys', () {
    expect(source, contains("String _prefKey(String userId, String key)"));
    expect(source, contains("'vsp_user_${userId}_$key'"));
    expect(source, contains('prefs.getBool(_prefKey(userId, key))'));
    expect(source, contains('prefs.setBool(_prefKey(userId, key), value)'));
    expect(source, isNot(contains("prefs.getBool('notif_general')")));
    expect(source, isNot(contains("prefs.setBool(key, value)")));
  });

  test('switching accounts invalidates stale async preference reads', () {
    expect(source, contains('context.watch<AuthProvider>().currentUser?.id'));
    expect(source, contains('if (_settingsUserId != userId)'));
    expect(source, contains('_loadSettings(userId)'));
    expect(source, contains('if (!mounted || _settingsUserId != userId) return;'));
  });

  test('signed-out preferences reset to defaults and cannot be saved', () {
    expect(source, contains('if (userId.isEmpty) {'));
    expect(source, contains('if (userId == null || userId.isEmpty) return;'));
    expect(source, contains('_generalNotifications = true;'));
  });
}
