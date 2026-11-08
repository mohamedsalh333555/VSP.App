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
    int normEnd = (end <= start) ? end + (24 * 60) : end;

    for (var breakEntry in breakTimes) {
      final bStart = breakEntry['start'];
      final bEnd = breakEntry['end'];
      if (bStart == null || bEnd == null) continue;

      final btStart = t(bStart);
      final btEnd = t(bEnd);

      int normBStart = (btStart < start && end <= start) ? btStart + (24 * 60) : btStart;
      int normBEnd = (btEnd < start && end <= start) ? btEnd + (24 * 60) : btEnd;

      if (!(normBStart >= start && normBEnd <= normEnd && normBStart < normBEnd)) {
        return false;
      }
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
