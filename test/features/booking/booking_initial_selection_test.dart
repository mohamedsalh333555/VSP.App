import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_initial_selection.dart';

void main() {
  final stadium = Stadium(
    id: 'fixture-venue',
    name: 'Fixture Pitch',
    location: 'Egypt',
    imageUrl: '',
    type: 'Football',
    size: '5 VS 5',
    baths: 0,
    cafeteria: 0,
    playersPerTeam: 5,
    totalFieldCapacity: 10,
    pricePerHour: 300,
    basePrice: 300,
    area: '800 m²',
    openingTime: '16:00',
    closingTime: '23:00',
  );
  final today = DateTime(2026, 11, 13);
  final now = DateTime(2026, 11, 13, 16);

  test('valid next-day contiguous slots survive normalization', () {
    final result = BookingInitialSelection.resolve(
      stadium: stadium,
      operationalBaseDate: today,
      now: now,
      requestedDate: DateTime(2026, 11, 14, 10),
      requestedSlots: const ['18:00', '18:30'],
    );
    expect(result.date, DateTime(2026, 11, 14));
    expect(result.slots, ['18:00', '18:30']);
  });

  test('slot-only link cannot assign an unbound old time to today', () {
    final result = BookingInitialSelection.resolve(
      stadium: stadium,
      operationalBaseDate: today,
      now: now,
      requestedDate: null,
      requestedSlots: const ['18:00'],
    );
    expect(result.date, today);
    expect(result.slots, isEmpty);
  });

  test('past date is clamped and stale slots are cleared before displaying total', () {
    final result = BookingInitialSelection.resolve(
      stadium: stadium,
      operationalBaseDate: today,
      now: now,
      requestedDate: DateTime(2026, 11, 11),
      requestedSlots: const ['18:00'],
    );
    expect(result.date, today);
    expect(result.slots, isEmpty);
  });

  test('out of supported four calendar months is clamped and cleared', () {
    final result = BookingInitialSelection.resolve(
      stadium: stadium,
      operationalBaseDate: today,
      now: now,
      requestedDate: DateTime(2027, 3, 1),
      requestedSlots: const ['18:00'],
    );
    expect(result.date, today);
    expect(result.slots, isEmpty);

    final lastAllowed = BookingInitialSelection.resolve(
      stadium: stadium,
      operationalBaseDate: today,
      now: now,
      requestedDate: DateTime(2027, 2, 28),
      requestedSlots: const ['18:00'],
    );
    expect(lastAllowed.slots, ['18:00']);
  });

  test('invalid, duplicated and nonadjacent route slot keys are ignored', () {
    for (final keys in <List<String>>[
      ['not-a-time'],
      ['18:00', '18:00'],
      ['18:00', '19:00'],
      [''],
      ['08:00'],
      ['18:00:30'],
    ]) {
      final result = BookingInitialSelection.resolve(
        stadium: stadium,
        operationalBaseDate: today,
        now: now,
        requestedDate: DateTime(2026, 11, 14),
        requestedSlots: keys,
      );
      expect(result.slots, isEmpty, reason: 'stale/untrusted keys: $keys');
    }
  });

  test('same-day slot already past is cleared even when the date is valid', () {
    final result = BookingInitialSelection.resolve(
      stadium: stadium,
      operationalBaseDate: today,
      now: DateTime(2026, 11, 13, 18, 45),
      requestedDate: today,
      requestedSlots: const ['18:00', '18:30'],
    );
    expect(result.date, today);
    expect(result.slots, isEmpty);
  });

  test('venue closure clears an otherwise valid initial selection', () {
    final blockedVenue = Stadium(
      id: 'blocked-fixture',
      name: 'Blocked Fixture Pitch',
      location: 'Egypt',
      imageUrl: '',
      type: 'Football',
      size: '5 VS 5',
      baths: 0,
      cafeteria: 0,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 300,
      basePrice: 300,
      area: '800 m²',
      openingTime: '16:00',
      closingTime: '23:00',
      isBlocked: true,
    );
    final result = BookingInitialSelection.resolve(
      stadium: blockedVenue,
      operationalBaseDate: today,
      now: now,
      requestedDate: DateTime(2026, 11, 14),
      requestedSlots: const ['18:00'],
    );
    expect(result.slots, isEmpty);
  });

  test('screen initialization adopts sanitized route selections', () {
    final source = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();
    expect(source, contains('BookingInitialSelection.resolve('));
    expect(source, contains('_selectedTimeSlots.addAll(initial.slots);'));
    expect(source, isNot(contains('_selectedTimeSlots.addAll(widget.initialSelectedSlots!)')));
  });
}
