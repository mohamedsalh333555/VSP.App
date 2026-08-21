import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Standardized Date & Time Formatter and Parser for VSP Application
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

  /// Format TimeOfDay to localized string (e.g., "08:30 م" or "08:30 PM")
  static String formatTimeOfDay(TimeOfDay? time, String defaultText, bool isArabic) {
    if (time == null) return defaultText;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am
        ? (isArabic ? 'ص' : 'AM')
        : (isArabic ? 'م' : 'PM');
    return '$hour:$minute $period';
  }

  /// Format hour and minute integers to string (e.g., "8:30 PM" or "8:30 م")
  static String formatHourMin(int h, int m, bool isArabic) {
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final period = isArabic ? (h >= 12 ? 'م' : 'ص') : (h >= 12 ? 'PM' : 'AM');
    final minute = m.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  /// Parse time strings like "04:00 PM" or "04:00 م" into total minutes from start of day (0 to 1439)
  static int parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return 0;
    try {
      final clean = timeStr.trim();
      final RegExp timeRegex = RegExp(r'(\d+)(?::(\d+))?\s*(AM|PM|ص|م|مساءً|صباحاً)?', caseSensitive: false);
      final match = timeRegex.firstMatch(clean);
      if (match == null) return 0;
      int hour = int.parse(match.group(1)!);
      int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
      String? period = match.group(3)?.toUpperCase();
      if ((period == 'PM' || period == 'م' || period == 'مساءً') && hour != 12) hour += 12;
      if ((period == 'AM' || period == 'ص' || period == 'صباحاً') && hour == 12) hour = 0;
      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }

  /// Parse time strings into 24-hour hour integer (0 to 23)
  static int parseTimeToHour(String? timeStr, {int defaultHour = 16}) {
    if (timeStr == null || timeStr.trim().isEmpty) return defaultHour;
    try {
      final totalMin = parseTimeToMinutes(timeStr);
      return totalMin ~/ 60;
    } catch (_) {
      return defaultHour;
    }
  }

  /// Format minutes into time string (12-hour format)
  static String formatMinutesToTime(int totalMinutes, bool isArabic) {
    int hour = (totalMinutes ~/ 60) % 24;
    int minute = totalMinutes % 60;
    final period = isArabic
        ? (hour >= 12 ? 'م' : 'ص')
        : (hour >= 12 ? 'PM' : 'AM');
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    final minStr = minute.toString().padLeft(2, '0');
    return '$hour:$minStr $period';
  }

  /// Short format for time ranges (e.g. "4:00 PM - 5:00 PM" -> "4 PM - 5 PM")
  static String formatTimeShort(String timeRange) {
    final parts = timeRange.split(' - ');
    if (parts.length == 2) {
      final start = parts[0].replaceAll(':00', '');
      final end = parts[1].replaceAll(':00', '');
      return '$start - $end';
    }
    return timeRange;
  }

  /// Localize common sport names
  static String getLocalizedSport(String sport, bool isArabic) {
    if (!isArabic) return sport;
    switch (sport.trim()) {
      case 'Football': return 'كرة القدم';
      case 'Basketball': return 'كرة السلة';
      case 'Volleyball': return 'الكرة الطائرة';
      case 'Padel': return 'بادل';
      case 'Handball': return 'كرة اليد';
      case 'Tennis': return 'تنس';
      default: return sport;
    }
  }

  /// Calculates the business operational date for bookings.
  /// Times between 12:00 AM and 05:59 AM belong to the previous day's operational shift.
  static DateTime getOperationalDate(DateTime dateTime) {
    if (dateTime.hour < 6) {
      final prev = dateTime.subtract(const Duration(days: 1));
      return DateTime(prev.year, prev.month, prev.day);
    }
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }
}
