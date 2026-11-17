/// Pure absolute-time and stable account-bound match reminder rules.
abstract final class VSPMatchReminderSchedule {
  static DateTime? reminderUtc({required DateTime matchTime, required DateTime now}) {
    final due = matchTime.toUtc().subtract(const Duration(hours: 2));
    return due.isAfter(now.toUtc()) ? due : null;
  }

  static String preferenceKey(String userId) =>
      'vsp_user_${userId}_scheduled_match_reminders';

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
