import 'package:flutter/material.dart';
import 'stadium_wizard_draft_service.dart';
import 'stadium_wizard_time_utils.dart';

/// Helper coordinating shift and break time selection and persistence for the stadium wizard.
class StadiumWizardTimeCoordinator {
  const StadiumWizardTimeCoordinator._();

  /// Prompts time picker for opening or closing shift and persists to draft if in creation mode.
  static Future<TimeOfDay?> selectShiftTime(
    BuildContext context, {
    required bool isMainStart,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required List<Map<String, TimeOfDay?>> breakTimes,
    required String? uid,
    required String? stadiumId,
  }) async {
    final initial = isMainStart
        ? (startTime ?? const TimeOfDay(hour: 16, minute: 0))
        : (endTime ?? const TimeOfDay(hour: 23, minute: 0));

    final picked = await StadiumWizardTimeUtils.selectTime(context, initialTime: initial);
    if (picked != null && stadiumId == null) {
      StadiumWizardDraftService.saveWorkingHours(
        uid,
        startTime: isMainStart ? picked : startTime,
        endTime: !isMainStart ? picked : endTime,
        breakTimes: breakTimes,
      );
    }
    return picked;
  }

  /// Prompts time picker for a specific break interval and updates draft persistence.
  static Future<TimeOfDay?> selectBreakTime(
    BuildContext context, {
    required int index,
    required bool isStart,
    required List<Map<String, TimeOfDay?>> breakTimes,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required String? uid,
    required String? stadiumId,
  }) async {
    final initial = isStart ? breakTimes[index]['start'] : breakTimes[index]['end'];
    final picked = await StadiumWizardTimeUtils.selectTime(
      context,
      initialTime: initial ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked != null) {
      int hour = picked.hour;
      int minute;
      if (picked.minute < 15) {
        minute = 0;
      } else if (picked.minute < 45) {
        minute = 30;
      } else {
        minute = 0;
        hour = (hour + 1) % 24;
      }
      final roundedTime = TimeOfDay(hour: hour, minute: minute);
      if (stadiumId == null) {
        if (index >= 0 && index < breakTimes.length) {
          breakTimes[index][isStart ? 'start' : 'end'] = roundedTime;
        }
        StadiumWizardDraftService.saveWorkingHours(
          uid,
          startTime: startTime,
          endTime: endTime,
          breakTimes: breakTimes,
        );
      }
      return roundedTime;
    }
    return null;
  }
}
