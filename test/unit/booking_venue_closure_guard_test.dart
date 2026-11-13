import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_calculator.dart';

void main() {
  Stadium venue({bool blocked = false, DateTime? closesAt}) =>
      Stadium.fromFirestore({
        'name': 'Synthetic Aswan Stadium',
        'opening_time': '16:00:00',
        'closing_time': '23:00:00',
        'is_verified': true,
        'is_blocked': blocked,
        if (closesAt != null)
          'maintenance_until': closesAt.toUtc().toIso8601String(),
      }, 'test_venue');

  test('administratively blocked venue refuses any booking slot', () {
    final now = DateTime.utc(2030, 5, 15, 12);
    expect(BookingSlotCalculator.isVenueSlotClosed(
      stadium: venue(blocked: true),
      slotStart: now.add(const Duration(days: 2)),
      now: now,
    ), isTrue);
  });

  test('active maintenance blocks earlier slots but not those after closure end', () {
    final now = DateTime.utc(2030, 5, 15, 12);
    final closeEnd = now.add(const Duration(hours: 3));
    final stadium = venue(closesAt: closeEnd);
    expect(BookingSlotCalculator.isVenueSlotClosed(
      stadium: stadium, slotStart: now.add(const Duration(hours: 1)), now: now,
    ), isTrue);
    expect(BookingSlotCalculator.isVenueSlotClosed(
      stadium: stadium, slotStart: closeEnd, now: now,
    ), isFalse);
    expect(BookingSlotCalculator.isVenueSlotClosed(
      stadium: stadium, slotStart: closeEnd.add(const Duration(minutes: 30)), now: now,
    ), isFalse);
  });

  test('expired maintenance marker never blocks a future slot', () {
    final now = DateTime.utc(2030, 5, 15, 12);
    final stadium = venue(closesAt: now.subtract(const Duration(hours: 2)));
    expect(BookingSlotCalculator.isVenueSlotClosed(
      stadium: stadium, slotStart: now.add(const Duration(days: 1)), now: now,
    ), isFalse);
  });

  test('venue with no maintenance marker remains open', () {
    final now = DateTime.utc(2030, 5, 15, 12);
    expect(BookingSlotCalculator.isVenueSlotClosed(
      stadium: venue(), slotStart: now.add(const Duration(hours: 1)), now: now,
    ), isFalse);
  });
}
