import 'package:intl/intl.dart';

/// Standardized Date Formatter for VSP Application
class AppDateFormatter {
  /// Format date as day and month (e.g., "15 أغسطس" in AR, "15 Aug" in EN)
  static String formatDayMonth(DateTime date, String locale) {
    if (locale.toLowerCase().startsWith('ar')) {
      final day = date.day;
      final monthName = DateFormat('MMMM', 'ar').format(date);
      return '$day $monthName';
    } else {
      return DateFormat('d MMM', 'en').format(date);
    }
  }

  /// Format date as day, month, and year (e.g., "15 أغسطس 2026" in AR, "15 Aug 2026" in EN)
  static String formatFullDate(DateTime date, String locale) {
    if (locale.toLowerCase().startsWith('ar')) {
      final day = date.day;
      final monthName = DateFormat('MMMM', 'ar').format(date);
      final year = date.year;
      return '$day $monthName $year';
    } else {
      return DateFormat('d MMM yyyy', 'en').format(date);
    }
  }

  /// Format time as hour and minute (e.g., "08:30 م" in AR, "08:30 PM" in EN)
  static String formatTime(DateTime date, String locale) {
    if (locale.toLowerCase().startsWith('ar')) {
      return DateFormat('hh:mm a', 'ar').format(date);
    } else {
      return DateFormat('hh:mm a', 'en').format(date);
    }
  }
}
