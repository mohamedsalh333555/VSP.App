import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_draft_service.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_time_utils.dart';

void main() {
  group('StadiumWizardTimeUtils Tests', () {
    test('parseTime handles valid HH:mm and HH:mm:ss strings', () {
      final t1 = StadiumWizardTimeUtils.parseTime('16:30');
      expect(t1, isNotNull);
      expect(t1!.hour, 16);
      expect(t1.minute, 30);

      final t2 = StadiumWizardTimeUtils.parseTime('08:00:00');
      expect(t2, isNotNull);
      expect(t2!.hour, 8);
      expect(t2.minute, 0);

      final t3 = StadiumWizardTimeUtils.parseTime(null);
      expect(t3, isNull);

      final t4 = StadiumWizardTimeUtils.parseTime('');
      expect(t4, isNull);
    });

    test('formatTime formats TimeOfDay with padding and default fallback', () {
      expect(StadiumWizardTimeUtils.formatTime(const TimeOfDay(hour: 9, minute: 5), '16:00:00'), '09:05:00');
      expect(StadiumWizardTimeUtils.formatTime(const TimeOfDay(hour: 23, minute: 45), '16:00:00'), '23:45:00');
      expect(StadiumWizardTimeUtils.formatTime(null, '16:00:00'), '16:00:00');
    });

    test('isSplitShiftValid returns true when split-shift is disabled', () {
      final isValid = StadiumWizardTimeUtils.isSplitShiftValid(
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: false,
        breakTimes: [],
      );
      expect(isValid, isTrue);
    });

    test('isSplitShiftValid validates breaks within regular same-day shift', () {
      // 16:00 to 23:00, break 18:00 to 19:00 -> Valid
      final valid = StadiumWizardTimeUtils.isSplitShiftValid(
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: true,
        breakTimes: [
          {'start': const TimeOfDay(hour: 18, minute: 0), 'end': const TimeOfDay(hour: 19, minute: 0)},
        ],
      );
      expect(valid, isTrue);

      // Break outside hours (14:00 to 15:00) -> Invalid
      final invalidBefore = StadiumWizardTimeUtils.isSplitShiftValid(
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: true,
        breakTimes: [
          {'start': const TimeOfDay(hour: 14, minute: 0), 'end': const TimeOfDay(hour: 15, minute: 0)},
        ],
      );
      expect(invalidBefore, isFalse);

      // Break inverted (end before start) -> Invalid
      final invalidInverted = StadiumWizardTimeUtils.isSplitShiftValid(
        startTime: const TimeOfDay(hour: 16, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 0),
        isSplitShift: true,
        breakTimes: [
          {'start': const TimeOfDay(hour: 19, minute: 0), 'end': const TimeOfDay(hour: 18, minute: 0)},
        ],
      );
      expect(invalidInverted, isFalse);
    });

    test('isSplitShiftValid validates breaks across overnight shifts (e.g. 20:00 to 04:00)', () {
      // 20:00 to 04:00 (+1 day), break 01:00 to 02:00 -> Valid
      final valid = StadiumWizardTimeUtils.isSplitShiftValid(
        startTime: const TimeOfDay(hour: 20, minute: 0),
        endTime: const TimeOfDay(hour: 4, minute: 0),
        isSplitShift: true,
        breakTimes: [
          {'start': const TimeOfDay(hour: 1, minute: 0), 'end': const TimeOfDay(hour: 2, minute: 0)},
        ],
      );
      expect(valid, isTrue);
    });
  });

  group('StadiumWizardDraftService Tests', () {
    test('getPrefix produces user-scoped and fallback keys correctly', () {
      expect(StadiumWizardDraftService.getPrefix('usr_123'), 'vsp_draft_stadium_usr_123_');
      expect(StadiumWizardDraftService.getPrefix(null), 'temp_stadium_');
      expect(StadiumWizardDraftService.getPrefix(''), 'temp_stadium_');
    });

    test('StadiumDraftData default initialization is safe and empty', () {
      const draft = StadiumDraftData();
      expect(draft.currentStep, 0);
      expect(draft.name, '');
      expect(draft.location, '');
      expect(draft.requireDeposit, isFalse);
      expect(draft.isSplitShift, isFalse);
      expect(draft.images, isEmpty);
      expect(draft.breakTimes, isEmpty);
    });
  });
}
