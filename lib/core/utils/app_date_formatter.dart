import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/egypt_governorates.dart';

/// Standardized Date & Time Formatter and Parser for VSP Application
class AppDateFormatter {
  /// Format date as day and month (e.g., "15 أغسطس" in AR, "15 Aug" in EN)
  static String formatDayMonth(DateTime date, String locale) {
    final localDate = date.toLocal();
    if (locale.toLowerCase().startsWith('ar')) {
      final day = localDate.day;
      final monthName = DateFormat('MMMM', 'ar').format(localDate);
      return '$day $monthName';
    } else {
      return DateFormat('d MMM', 'en').format(localDate);
    }
  }

  /// Format date as day, month, and year (e.g., "15 أغسطس 2026" in AR, "15 Aug 2026" in EN)
  static String formatFullDate(DateTime date, String locale) {
    final localDate = date.toLocal();
    if (locale.toLowerCase().startsWith('ar')) {
      final day = localDate.day;
      final monthName = DateFormat('MMMM', 'ar').format(localDate);
      final year = localDate.year;
      return '$day $monthName $year';
    } else {
      return DateFormat('d MMM yyyy', 'en').format(localDate);
    }
  }

  /// Format time as hour and minute (e.g., "08:30 م" in AR, "08:30 PM" in EN)
  static String formatTime(DateTime date, String locale) {
    final localDate = date.toLocal();
    final isArabic = locale.toLowerCase().startsWith('ar');
    try {
      if (isArabic) {
        return DateFormat('hh:mm a', 'ar').format(localDate);
      } else {
        return DateFormat('hh:mm a', 'en').format(localDate);
      }
    } catch (_) {
      return formatHourMin(localDate.hour, localDate.minute, isArabic);
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
  /// Parse a full 12/24-hour time. Returns null for malformed input.
  /// Midnight (00:00) is a valid zero, unlike a parse failure.
  static int? tryParseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    var clean = timeStr.trim();
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    for (var i = 0; i < 10; i++) {
      clean = clean.replaceAll(eastern[i], i.toString());
      clean = clean.replaceAll(persian[i], i.toString());
    }
    clean = clean.replaceAll('：', ':');
    final match = RegExp(
      r'^(\d{1,2})(?::(\d{1,2}))?\s*(AM|PM|ص|م|مساءً|صباحاً)?$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '0');
    if (minute == null || minute > 59) return null;
    final period = match.group(3)?.toUpperCase();
    if (period != null) {
      if (hour < 1 || hour > 12) return null;
      if (period == 'PM' || period == 'م' || period == 'مساءً') {
        if (hour != 12) hour += 12;
      } else if (hour == 12) {
        hour = 0;
      }
    } else if (hour > 23) {
      return null;
    }
    return hour * 60 + minute;
  }

  /// Legacy callers expect midnight for invalid input.
  static int parseTimeToMinutes(String? timeStr) =>
      tryParseTimeToMinutes(timeStr) ?? 0;

  /// Parse time into 24-hour hour; preserve defaultHour for invalid input.
  static int parseTimeToHour(String? timeStr, {int defaultHour = 16}) =>
      (tryParseTimeToMinutes(timeStr) ?? (defaultHour * 60)) ~/ 60;

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

  /// Localize common sport names using the central registry
  static String getLocalizedSport(String sport, bool isArabic) {
    return EgyptGovernorates.getLocalizedSport(sport, isArabic);
  }

  /// Calculates the business operational date for bookings.
  /// Times between 12:00 AM and [shiftStartHour] (default 6:00 AM) belong to the previous day's operational shift.
  static DateTime getOperationalDate(DateTime dateTime, {int shiftStartHour = 6}) {
    final local = dateTime.toLocal();
    if (local.hour < shiftStartHour) {
      final prev = local.subtract(const Duration(days: 1));
      return DateTime(prev.year, prev.month, prev.day);
    }
    return DateTime(local.year, local.month, local.day);
  }
}
