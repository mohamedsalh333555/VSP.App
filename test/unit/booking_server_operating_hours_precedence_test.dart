import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_calculator.dart';

void main() {
  Stadium live(Map<String, dynamic> extra) {
    return Stadium.fromFirestore({
      'name': 'Synthetic Aswan Venue',
      'is_verified': true,
      'opening_time': '16:00:00',
      'closing_time': '20:00:00',
      ...extra,
    }, 'synthetic_server_hours');
  }

  test('SQL opening and closing columns outrank stale feature JSON hours', () {
    final stadium = live({
      'features': {
        'workingHours': {'start': '06:00', 'end': '08:00'},
      },
    });
    expect(stadium.hasServerOperatingHours, isTrue);
    final slots = BookingSlotCalculator.generateDynamicTimeSlots(
      stadium: stadium, isArabic: false,
    );
    expect(slots, hasLength(8));
    expect(slots.first.startMinutes, 16 * 60);
    expect(slots.last.startMinutes, 19 * 60 + 30);
    expect(
      () => BookingSlotCalculator.getSlotDateTime(
        slotKey: '06:00:00',
        stadium: stadium,
        selectedDate: DateTime(2030, 1, 1),
      ),
      throwsFormatException,
    );
  });

  test('SQL split shift enforces break even with no feature JSON', () {
    final stadium = live({
      'is_split_shift': true,
      'break_start_time': '18:00:00',
      'break_end_time': '19:00:00',
      'features': <String, dynamic>{},
    });
    expect(stadium.isSplitShift, isTrue);
    expect(stadium.breakStartTime, '18:00:00');
    final slots = BookingSlotCalculator.generateDynamicTimeSlots(
      stadium: stadium, isArabic: false,
    );
    expect(slots, hasLength(6));
    expect(slots.any((s) => s.startMinutes == 18 * 60), isFalse);
    expect(slots.any((s) => s.startMinutes == 18 * 60 + 30), isFalse);
    expect(
      () => BookingSlotCalculator.getSlotDateTime(
        slotKey: '18:00:00',
        stadium: stadium,
        selectedDate: DateTime(2030, 1, 1),
      ),
      throwsFormatException,
    );
  });

  test('SQL after-midnight break is resolved within the overnight shift', () {
    final stadium = live({
      'opening_time': '22:00:00',
      'closing_time': '02:00:00',
      'is_split_shift': true,
      'break_start_time': '00:00:00',
      'break_end_time': '01:00:00',
    });
    final slots = BookingSlotCalculator.generateDynamicTimeSlots(
      stadium: stadium, isArabic: false,
    );
    expect(slots, hasLength(6));
    expect(slots.any((s) => s.startMinutes == 24 * 60), isFalse);
    expect(slots.any((s) => s.startMinutes == 24 * 60 + 30), isFalse);
    expect(
      () => BookingSlotCalculator.getSlotDateTime(
        slotKey: '00:00:00',
        stadium: stadium,
        selectedDate: DateTime(2030, 1, 1),
      ),
      throwsFormatException,
    );
  });

  test('conflicting overlapping feature/server breaks fail closed', () {
    final stadium = live({
      'is_split_shift': true,
      'break_start_time': '18:00:00',
      'break_end_time': '19:00:00',
      'features': {
        'breakTimes': [
          {'start': '18:30', 'end': '19:30'},
        ],
      },
    });
    expect(
      BookingSlotCalculator.generateDynamicTimeSlots(
        stadium: stadium, isArabic: false,
      ),
      isEmpty,
    );
  });

  test('unconfigured split shift fails closed rather than ignoring server flag', () {
    final stadium = live({
      'is_split_shift': true,
      'break_start_time': null,
      'break_end_time': null,
    });
    expect(
      BookingSlotCalculator.generateDynamicTimeSlots(
        stadium: stadium, isArabic: false,
      ),
      isEmpty,
    );
  });

  test('feature-only offline test stadium retains backwards-compatible hours', () {
    final stadium = Stadium.fromFirestore({
      'name': 'Synthetic legacy pitch',
      'features': {
        'workingHours': {'start': '16:00', 'end': '20:00'},
      },
    }, 'legacy_schedule');
    expect(stadium.hasServerOperatingHours, isFalse);
    expect(BookingSlotCalculator.generateDynamicTimeSlots(
      stadium: stadium, isArabic: false,
    ), hasLength(8));
  });
}
