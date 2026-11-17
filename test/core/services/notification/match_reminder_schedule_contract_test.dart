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
    expect(schedule, contains('VSPMatchReminderSchedule.allowsScheduling('));
    expect(schedule, contains('VSPMatchReminderSchedule.withScheduled('));
    expect(schedule, contains('await cancelObsoleteReminder();'));
    expect(service, contains('VSPMatchReminderSchedule.notificationIdFromRecord(raw)'));
    final out = File('lib/core/providers/auth/auth_sign_out_handler.dart').readAsStringSync();
    expect(out.indexOf('cancelScheduledMatchRemindersForUser(user.id)'),
        lessThan(out.indexOf('await authService.signOut()')));
  });

  test('daily quota caps at 3, while same booking reschedules without extra slots', () {
    final day = DateTime.utc(2026, 11, 17, 18);
    final records = [
      for (var i = 1; i <= 3; i++) VSPMatchReminderSchedule.quotaRecord(i, day),
    ];
    expect(VSPMatchReminderSchedule.maxRemindersPerUtcDay, 3);
    expect(VSPMatchReminderSchedule.allowsScheduling(
      records: records, notificationId: 4, reminderUtc: day,
    ), isFalse);
    expect(VSPMatchReminderSchedule.allowsScheduling(
      records: records, notificationId: 2, reminderUtc: day,
    ), isTrue);
    expect(VSPMatchReminderSchedule.allowsScheduling(
      records: records, notificationId: 4,
      reminderUtc: DateTime.utc(2026, 11, 18),
    ), isTrue);
  });

  test('booking move replaces old UTC day, legacy numeric IDs remain cancellable', () {
    final from = DateTime.utc(2026, 11, 17, 18);
    final records = VSPMatchReminderSchedule.withScheduled(
      records: [
        VSPMatchReminderSchedule.quotaRecord(200, from),
        VSPMatchReminderSchedule.quotaRecord(201, from),
        '190',
      ],
      notificationId: 200, reminderUtc: DateTime.utc(2026, 11, 18, 18),
    );
    expect(records.where((s) => s.endsWith('|200')).length, 1);
    expect(records.any((s) => s.startsWith('2026-11-18|200')), isTrue);
    expect(records.any((s) => s.startsWith('2026-11-17|200')), isFalse);
    expect(VSPMatchReminderSchedule.notificationIdFromRecord('190'), 190);
    expect(VSPMatchReminderSchedule.notificationIdFromRecord('2026-11-18|200'), 200);
    expect(VSPMatchReminderSchedule.notificationIdFromRecord('invalid'), isNull);
  });

  test('an invalid or moved booking may invalidate an older native reminder', () {
    final before = <String>[
      VSPMatchReminderSchedule.quotaRecord(99, DateTime.utc(2026, 11, 17)),
      VSPMatchReminderSchedule.quotaRecord(100, DateTime.utc(2026, 11, 17)),
      '101',
    ];
    final after = VSPMatchReminderSchedule.withoutScheduled(
      records: before, notificationId: 99,
    );
    expect(after.length, 2);
    expect(after.any((record) => record.endsWith('|99')), isFalse);
    expect(after.any((record) => record.endsWith('|100')), isTrue);
    expect(after.contains('101'), isTrue);
  });
}
