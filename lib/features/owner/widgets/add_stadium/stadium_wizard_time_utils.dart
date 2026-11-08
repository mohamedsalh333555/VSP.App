import 'package:flutter/material.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/app_date_formatter.dart';

class StadiumWizardTimeUtils {
  static TimeOfDay? parseTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$')
        .firstMatch(timeStr.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null ||
        hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String formatTime(TimeOfDay? time, String defaultTime24) {
    if (time == null) return defaultTime24;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  static bool isSplitShiftValid({
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required bool isSplitShift,
    required List<Map<String, TimeOfDay?>> breakTimes,
  }) {
    if (!isSplitShift) return true;
    if (startTime == null || endTime == null) return true;

    int t(TimeOfDay time) => time.hour * 60 + time.minute;
    final start = t(startTime);
    final end = t(endTime);
    final overnight = end <= start;
    final normalizedEnd = overnight ? end + 24 * 60 : end;
    final intervals = <({int start, int end})>[];

    for (final breakEntry in breakTimes) {
      final breakStart = breakEntry['start'];
      final breakEnd = breakEntry['end'];
      // An incomplete closure must not silently become a bookable interval.
      if (breakStart == null || breakEnd == null) return false;

      var normalizedStart = t(breakStart);
      var normalizedBreakEnd = t(breakEnd);
      if (overnight && normalizedStart < start) normalizedStart += 24 * 60;
      if (overnight && normalizedBreakEnd < start) normalizedBreakEnd += 24 * 60;

      if (normalizedStart < start ||
          normalizedBreakEnd > normalizedEnd ||
          normalizedStart >= normalizedBreakEnd) {
        return false;
      }
      intervals.add((start: normalizedStart, end: normalizedBreakEnd));
    }

    intervals.sort((a, b) => a.start.compareTo(b.start));
    for (var i = 1; i < intervals.length; i++) {
      if (intervals[i].start < intervals[i - 1].end) return false;
    }
    return true;
  }

  static Future<TimeOfDay?> selectTime(
    BuildContext context, {
    required TimeOfDay initialTime,
  }) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (pickerCtx, child) => MediaQuery(
        data: MediaQuery.of(pickerCtx).copyWith(alwaysUse24HourFormat: false),
        child: Theme(
          data: Theme.of(pickerCtx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: VSPColors.accent,
              onPrimary: Colors.black,
              surface: VSPColors.surface,
              onSurface: VSPColors.textPrimary,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: VSPColors.surface,
              dialBackgroundColor: VSPColors.surfaceAlt,
              dayPeriodColor: WidgetStateColor.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? VSPColors.accent
                      : VSPColors.surfaceAlt),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? Colors.black
                      : VSPColors.textSecondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VSPRadius.xl),
              ),
            ),
          ),
          child: child!,
        ),
      ),
    );

    return picked;
  }
}
