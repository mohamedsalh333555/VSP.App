import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('general and match reminder opt-out cancels pending reminders after save', () {
    final screen = File(
      'lib/features/player/screens/profile_subscreens/notifications_screen.dart',
    ).readAsStringSync();
    for (final key in ['notif_general', 'notif_match_reminders']) {
      final saving = screen.indexOf("await _saveSetting('$key', v)");
      final commit = screen.indexOf('setState(() =>', saving);
      final condition = screen.indexOf('if (!v && requestUserId != null', commit);
      final cancel = screen.indexOf(
        '.cancelScheduledMatchRemindersForUser(requestUserId)', condition,
      );
      expect(saving, greaterThan(0), reason: key);
      expect(commit, greaterThan(saving), reason: key);
      expect(condition, greaterThan(commit), reason: key);
      expect(cancel, greaterThan(condition), reason: key);
      expect(cancel - saving, lessThan(800), reason: key);
    }
  });

  test('sign out cancels user reminders before invalidating the JWT', () {
    final signOut = File('lib/core/providers/auth/auth_sign_out_handler.dart')
        .readAsStringSync();
    final cancel = signOut.indexOf('cancelScheduledMatchRemindersForUser(user.id)');
    final revoke = signOut.indexOf('await authService.signOut()');
    expect(cancel, greaterThan(0));
    expect(revoke, greaterThan(cancel));
  });
}
