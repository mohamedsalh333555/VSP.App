/// Pure absolute-time and stable account-bound match reminder rules.
abstract final class VSPMatchReminderSchedule {
  static DateTime? reminderUtc({required DateTime matchTime, required DateTime now}) {
    final due = matchTime.toUtc().subtract(const Duration(hours: 2));
    return due.isAfter(now.toUtc()) ? due : null;
  }

  static String preferenceKey(String userId) =>
      'vsp_user_${userId}_scheduled_match_reminders';


  /// Local best-effort quota of three reminders per account per UTC day.
  static const int maxRemindersPerUtcDay = 3;

  static String _dayUtc(DateTime instant) {
    final d = instant.toUtc();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static int? notificationIdFromRecord(String record) {
    final value = record.contains('|') ? record.split('|').last : record;
    final id = int.tryParse(value);
    return id != null && id >= 0 ? id : null;
  }

  static String quotaRecord(int notificationId, DateTime reminderUtc) =>
      '${_dayUtc(reminderUtc)}|$notificationId';

  static bool allowsScheduling({
    required Iterable<String> records,
    required int notificationId,
    required DateTime reminderUtc,
  }) {
    final day = _dayUtc(reminderUtc);
    final todays = <int>{};
    for (final record in records) {
      if (!record.startsWith('$day|')) continue;
      final oldId = notificationIdFromRecord(record);
      if (oldId == notificationId) return true;
      if (oldId != null) todays.add(oldId);
    }
    return todays.length < maxRemindersPerUtcDay;
  }

  static List<String> withScheduled({
    required Iterable<String> records,
    required int notificationId,
    required DateTime reminderUtc,
  }) {
    final next = <String>{
      for (final record in records)
        if (notificationIdFromRecord(record) != notificationId) record,
    };
    next.add(quotaRecord(notificationId, reminderUtc));
    return List<String>.unmodifiable(next);
  }

  static int reminderId(String userId, String bookingId) {
    if (userId.trim().isEmpty || bookingId.trim().isEmpty) {
      throw ArgumentError('User and booking required');
    }
    final key = '${userId.length}:$userId:$bookingId';
    var hash = 0x811C9DC5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}
