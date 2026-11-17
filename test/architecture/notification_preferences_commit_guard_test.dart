import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/player/screens/profile_subscreens/notifications_screen.dart',
  ).readAsStringSync();

  test('every notification switch waits for successful save before UI commit', () {
    const keys = [
      'notif_general',
      'notif_sound',
      'notif_chat',
      'notif_owner_new_bookings',
      'notif_owner_payouts',
      'notif_owner_daily_schedule',
      'notif_cash_bookings',
      'notif_match_reminders',
      'notif_team_transfers',
      'notif_challenge_results',
    ];
    expect(source, contains('Future<bool> _saveSetting(String key, bool value) async'));
    expect(source, contains('final saved = await prefs.setBool('));
    expect(source, contains('return saved;'));
    expect(source, contains('return false;'));
    for (final key in keys) {
      final prefix = "await _saveSetting('$key', v)";
      final start = source.indexOf(prefix);
      expect(start, greaterThan(0), reason: key);
      final nextSetState = source.indexOf('setState(() =>', start);
      final scopedGuard = source.indexOf(
        'mounted && _settingsUserId == requestUserId', start,
      );
      expect(scopedGuard, greaterThan(start), reason: key);
      expect(nextSetState, greaterThan(scopedGuard), reason: key);
      expect(nextSetState - start, lessThan(300), reason: key);
    }
  });

  test('an account switch prevents old preference write changing new account UI', () {
    expect(source, contains('final requestUserId = _settingsUserId;'));
    expect(source, contains('if (!mounted || _settingsUserId != userId) return false;'));
    expect(source, contains('mounted && _settingsUserId == requestUserId'));
    expect(source, isNot(contains("setState(() => _generalNotifications = v);\n                       _saveSetting(")));
  });
}
