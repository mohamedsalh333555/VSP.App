import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_calculator.dart';

void main() {
  Stadium stadium({
    required String opening,
    required String closing,
    Map<String, dynamic> features = const {},
  }) {
    return Stadium(
      id: 'stadium_missing_hours',
      name: 'Synthetic Aswan Stadium',
      location: 'Aswan',
      ownerId: 'synthetic_owner',
      imageUrl: '',
      type: 'Football',
      size: '5 VS 5',
      baths: 0,
      cafeteria: 0,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 100,
      basePrice: 100,
      area: '600',
      openingTime: opening,
      closingTime: closing,
      features: features,
    );
  }

  test('no configured stadium hours must not fabricate slots', () {
    final venue = stadium(opening: '', closing: '');
    expect(
      BookingSlotCalculator.generateDynamicTimeSlots(
        stadium: venue,
        isArabic: true,
      ),
      isEmpty,
    );
    expect(
      () => BookingSlotCalculator.getSlotDateTime(
        slotKey: '16:00:00',
        stadium: venue,
        selectedDate: DateTime(2030, 1, 1),
      ),
      throwsFormatException,
    );
  });

  test('partial schedule is also unavailable', () {
    final venue = stadium(opening: '16:00', closing: '');
    expect(
      BookingSlotCalculator.generateDynamicTimeSlots(
        stadium: venue,
        isArabic: false,
      ),
      isEmpty,
    );
    expect(
      () => BookingSlotCalculator.getSlotDateTime(
        slotKey: '16:00:00',
        stadium: venue,
        selectedDate: DateTime(2030, 1, 1),
      ),
      throwsFormatException,
    );
  });

  test('explicit valid workingHours override still generates slots', () {
    final venue = stadium(
      opening: '',
      closing: '',
      features: {
        'workingHours': {'start': '16:00', 'end': '20:00'},
      },
    );
    final slots = BookingSlotCalculator.generateDynamicTimeSlots(
      stadium: venue,
      isArabic: false,
    );
    expect(slots, hasLength(8));
    expect(
      BookingSlotCalculator.getSlotDateTime(
        slotKey: '16:00:00',
        stadium: venue,
        selectedDate: DateTime(2030, 1, 1),
      ).hour,
      16,
    );
  });
}
