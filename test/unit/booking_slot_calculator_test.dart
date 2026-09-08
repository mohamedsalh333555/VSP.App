import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_calculator.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_models.dart';

void main() {
  group('BookingSlotCalculator Unit Tests', () {
    final testStadium = Stadium(
      id: 'std_123',
      name: 'Bernabeu Arena',
      location: 'Nasr City, Cairo',
      ownerId: 'own_1',
      imageUrl: 'https://example.com/stadium.jpg',
      type: 'Football',
      size: '5 VS 5',
      baths: 1,
      cafeteria: 1,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 400.0,
      basePrice: 400.0,
      area: '800 m²',
      openingTime: '04:00 PM',
      closingTime: '11:00 PM',
      features: {
        'workingHours': {
          'start': '16:00',
          'end': '23:00',
        },
      },
    );

    test('generateDynamicTimeSlots creates 30-min intervals correctly', () {
      final slots = BookingSlotCalculator.generateDynamicTimeSlots(
        stadium: testStadium,
        isArabic: false,
      );

      // 16:00 to 23:00 = 7 hours = 14 intervals of 30 minutes
      expect(slots.length, 14);
      expect(slots.first.startMinutes, 16 * 60);
      expect(slots.last.startMinutes, 22 * 60 + 30);
    });

    test('generateDynamicTimeSlots skips break time slots', () {
      final stadiumWithBreak = Stadium(
        id: 'std_break',
        name: 'Break Stadium',
        location: 'Cairo',
        ownerId: 'own_1',
        imageUrl: 'https://example.com/break.jpg',
        type: 'Football',
        size: '5 VS 5',
        baths: 1,
        cafeteria: 1,
        playersPerTeam: 5,
        totalFieldCapacity: 10,
        pricePerHour: 300.0,
        basePrice: 300.0,
        area: '600 m²',
        features: {
          'workingHours': {'start': '16:00', 'end': '20:00'}, // 4 hours = 8 slots
          'breakTime': {'start': '18:00', 'end': '19:00'}, // 1 hour = 2 slots skipped
        },
      );

      final slots = BookingSlotCalculator.generateDynamicTimeSlots(
        stadium: stadiumWithBreak,
        isArabic: false,
      );

      // 8 total slots - 2 break slots = 6 active slots
      expect(slots.length, 6);
      for (final slot in slots) {
        expect(slot.startMinutes < (18 * 60) || slot.startMinutes >= (19 * 60), isTrue);
      }
    });

    test('getSlotDateTime resolves correct hour and minute', () {
      final date = DateTime(2026, 9, 15);
      final dt = BookingSlotCalculator.getSlotDateTime(
        slotKey: '16:30:00',
        stadium: testStadium,
        selectedDate: date,
      );

      expect(dt.year, 2026);
      expect(dt.month, 9);
      expect(dt.day, 15);
      expect(dt.hour, 16);
      expect(dt.minute, 30);
    });

    test('calculateNewSelectedSlots handles single selection and toggle-off', () {
      final date = DateTime(2026, 9, 15);
      final slots = <TimeSlotItem>[
        TimeSlotItem(startTime: '04:00 PM', endTime: '04:30 PM', key: '16:00:00', startMinutes: 960),
        TimeSlotItem(startTime: '04:30 PM', endTime: '05:00 PM', key: '16:30:00', startMinutes: 990),
      ];

      // 1. Initial selection
      final s1 = BookingSlotCalculator.calculateNewSelectedSlots(
        slotKey: '16:00:00',
        currentSelectedSlots: [],
        timeSlots: slots,
        stadium: testStadium,
        selectedDate: date,
        existingBookings: [],
      );
      expect(s1, ['16:00:00']);

      // 2. Toggle off
      final s2 = BookingSlotCalculator.calculateNewSelectedSlots(
        slotKey: '16:00:00',
        currentSelectedSlots: s1,
        timeSlots: slots,
        stadium: testStadium,
        selectedDate: date,
        existingBookings: [],
      );
      expect(s2, isEmpty);
    });

    test('calculateNewSelectedSlots builds contiguous range for 2-point selection', () {
      final date = DateTime(2026, 12, 1); // Future date to bypass past checks
      final slots = <TimeSlotItem>[
        TimeSlotItem(startTime: '04:00 PM', endTime: '04:30 PM', key: '16:00:00', startMinutes: 960),
        TimeSlotItem(startTime: '04:30 PM', endTime: '05:00 PM', key: '16:30:00', startMinutes: 990),
        TimeSlotItem(startTime: '05:00 PM', endTime: '05:30 PM', key: '17:00:00', startMinutes: 1020),
      ];

      final range = BookingSlotCalculator.calculateNewSelectedSlots(
        slotKey: '17:00:00',
        currentSelectedSlots: ['16:00:00'],
        timeSlots: slots,
        stadium: testStadium,
        selectedDate: date,
        existingBookings: [],
      );

      // Should automatically include the intermediate slot 16:30:00
      expect(range, ['16:00:00', '16:30:00', '17:00:00']);
    });
  });
}
