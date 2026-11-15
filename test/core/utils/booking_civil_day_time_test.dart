import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/app_date_formatter.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_calculator.dart';

void main() {
  test('civil days cross month and leap-year boundaries exactly once', () {
    final start = DateTime(2028, 2, 27);
    final days = List.generate(4, (i) => AppDateFormatter.addCivilDays(start, i));
    expect(days.map((d) => [d.year,d.month,d.day].join('-')).toList(), [
      '2028-2-27', '2028-2-28', '2028-2-29', '2028-3-1',
    ]);
    expect(days.every((date) => date.hour == 0 && date.minute == 0), isTrue);
  });

  test('Egyptian DST transition weeks yield 14 distinct consecutive civil dates', () {
    for (final start in [
      DateTime(2026, 4, 22),
      DateTime(2026, 10, 27),
    ]) {
      final days = List.generate(
        14, (i) => AppDateFormatter.addCivilDays(start, i),
      );
      expect(days.toSet().length, 14);
      for (var i = 1; i < days.length; i++) {
        final expected = DateTime(start.year, start.month, start.day + i);
        expect([days[i].year,days[i].month,days[i].day],
               [expected.year,expected.month,expected.day]);
        // Cairo's spring transition has no local 00:00, so that day can
        // naturally normalize to 01:00; compare civil calendar identity.
        expect(days[i].hour, expected.hour);
      }
    }
  });

  test('civil next date resets local time rather than adding 24 elapsed hours', () {
    final following = AppDateFormatter.addCivilDays(
      DateTime(2026, 10, 29, 16, 30), 1,
    );
    expect(following, DateTime(2026, 10, 30));
  });
  test('operational date goes to previous civil day before shift cutoff', () {
    final early = DateTime(2026, 4, 24, 1, 30);
    final businessDate = AppDateFormatter.getOperationalDate(early);
    expect(
      [businessDate.year, businessDate.month, businessDate.day],
      [2026, 4, 23],
    );
    final late = AppDateFormatter.getOperationalDate(DateTime(2026, 10, 30, 9));
    expect(
      [late.year, late.month, late.day],
      [2026, 10, 30],
    );
  });

  test('Cairo spring gap never maps skipped midnight slots onto 01:00', () {
    if (Platform.environment['TZ'] != 'Africa/Cairo') return;
    expect(DateTime(2026, 4, 24).hour, 1);
    final stadium = Stadium(
      id: 'dst-pitch',
      name: 'DST fixture',
      location: 'Aswan',
      imageUrl: '',
      type: 'Football',
      size: '5 vs 5',
      baths: 0,
      cafeteria: 0,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 200,
      area: 'Aswan',
      openingTime: '22:00',
      closingTime: '02:00',
    );
    final businessDate = DateTime(2026, 4, 23);
    for (final skipped in ['00:00', '00:30']) {
      expect(
        () => BookingSlotCalculator.getSlotDateTime(
          slotKey: skipped,
          stadium: stadium,
          selectedDate: businessDate,
        ),
        throwsFormatException,
      );
    }
    final before = BookingSlotCalculator.getSlotDateTime(
      slotKey: '23:30', stadium: stadium, selectedDate: businessDate,
    );
    final after = BookingSlotCalculator.getSlotDateTime(
      slotKey: '01:00', stadium: stadium, selectedDate: businessDate,
    );
    expect([after.year, after.month, after.day, after.hour], [2026, 4, 24, 1]);
    expect(after.toUtc().difference(before.toUtc()), const Duration(minutes: 30));
  });

}
