import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/notification/match_reminder_schedule_contract.dart';

void main() {
  test('reminders use two-hour advance UTC instant, including Cairo DST', () {
    final match = DateTime.parse('2026-04-24T21:00:00+03:00');
    expect(VSPMatchReminderSchedule.reminderUtc(
      matchTime: match, now: DateTime.utc(2026, 4, 24, 12),
    ), DateTime.utc(2026, 4, 24, 16));
    expect(VSPMatchReminderSchedule.reminderUtc(
      matchTime: match, now: DateTime.utc(2026, 4, 24, 16),
    ), isNull);
  });

  test('stable native notification IDs belong to account and booking pair', () {
    final a = VSPMatchReminderSchedule.reminderId('u-a', 'book-1');
    expect(VSPMatchReminderSchedule.reminderId('u-a', 'book-1'), a);
    expect(VSPMatchReminderSchedule.reminderId('u-b', 'book-1'), isNot(a));
    expect(VSPMatchReminderSchedule.reminderId('u-a', 'book-2'), isNot(a));
    expect(() => VSPMatchReminderSchedule.reminderId('', 'book-2'), throwsArgumentError);
  });

  test('match reminder is scheduled, not shown immediately, and cancelled on logout', () {
    final service = File('lib/core/services/notification_service.dart').readAsStringSync();
    final start = service.indexOf('Future<void> scheduleMatchReminder(');
    final end = service.indexOf('Future<void> cancelScheduledMatchRemindersForUser(', start);
    final schedule = service.substring(start, end);
    expect(schedule, contains('_localNotifications.zonedSchedule('));
    expect(schedule, isNot(contains('_localNotifications.show(')));
    expect(schedule, contains('AndroidScheduleMode.inexactAllowWhileIdle'));
    expect(schedule, contains('UILocalNotificationDateInterpretation.absoluteTime'));
    expect(schedule, contains("'recipientUserId': userId"));
    expect(schedule, contains("'bookingId': bookingId"));
    expect(schedule, contains('await _localNotifications.cancel(id)'));
    expect(schedule, contains('prefs.setStringList(key, ids.toList())'));
    final out = File('lib/core/providers/auth/auth_sign_out_handler.dart').readAsStringSync();
    expect(out.indexOf('cancelScheduledMatchRemindersForUser(user.id)'),
        lessThan(out.indexOf('await authService.signOut()')));
  });
}
