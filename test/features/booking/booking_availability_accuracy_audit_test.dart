import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_calculator.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_models.dart';

Stadium pitch() => Stadium(
  id: 'pitch-a',
  name: 'Fixture Pitch',
  location: 'Alexandria',
  imageUrl: '',
  type: 'Football',
  size: '5 VS 5',
  baths: 0,
  cafeteria: 0,
  playersPerTeam: 5,
  totalFieldCapacity: 10,
  pricePerHour: 200,
  area: 'Alexandria',
  isVerified: true,
  openingTime: '04:00 PM',
  closingTime: '08:00 PM',
);

Booking reservation(
  String id,
  DateTime start, {
  BookingStatus status = BookingStatus.confirmed,
  String venue = 'pitch-a',
  int minutes = 30,
}) => Booking(
  id: id,
  ownerId: 'fixture-owner',
  stadiumId: venue,
  stadiumName: 'Fixture Pitch',
  startTime: start,
  endTime: start.add(Duration(minutes: minutes)),
  bookingType: BookingType.personal,
  isPrivate: true,
  rentBall: false,
  totalPrice: 100,
  paymentMethod: 'cash',
  status: status,
  createdByUserId: 'fixture-player',
  createdAt: DateTime(2026, 11, 1),
);

final reportDate = DateTime(2030, 1, 15);

void main() {
  test('real overlap blocks each half-hour and preserves adjacent free time', () {
    final stadium = pitch();
    final starts = BookingSlotCalculator.generateDynamicTimeSlots(
      stadium: stadium, isArabic: false,
    );
    expect(starts, hasLength(8));
    final reserved = BookingSlotCalculator.getSlotDateTime(
      slotKey: starts[1].key,
      stadium: stadium,
      selectedDate: reportDate,
    );
    final bookings = [
      reservation('confirmed', reserved, minutes: 60),
    ];
    bool booked(TimeSlotItem item) => BookingSlotCalculator.isSlotBooked(
      slotKey: item.key,
      stadium: stadium,
      selectedDate: reportDate,
      existingBookings: bookings,
    );
    expect(booked(starts[0]), isFalse);
    expect(booked(starts[1]), isTrue);
    expect(booked(starts[2]), isTrue);
    expect(booked(starts[3]), isFalse);
  });

  test('venue identifiers with different case/whitespace still block booking', () {
    final stadium = pitch();
    final date = BookingSlotCalculator.getSlotDateTime(
      slotKey: '4:00 PM',
      stadium: stadium,
      selectedDate: reportDate,
    );
    expect(BookingSlotCalculator.isSlotBooked(
      slotKey: '4:00 PM',
      stadium: stadium,
      selectedDate: reportDate,
      existingBookings: [
        reservation('same-venue', date, venue: ' PITCH-A '),
      ],
    ), isTrue);
  });

  test('pending is held, cancelled and expired releases do not block other slots', () {
    final stadium = pitch();
    final date = BookingSlotCalculator.getSlotDateTime(
      slotKey: '4:00 PM',
      stadium: stadium,
      selectedDate: reportDate,
    );

    bool booked(BookingStatus status) => BookingSlotCalculator.isSlotBooked(
      slotKey: '4:00 PM',
      stadium: stadium,
      selectedDate: reportDate,
      existingBookings: [reservation('booking', date, status: status)],
    );
    expect(booked(BookingStatus.pending), isTrue);
    expect(booked(BookingStatus.confirmed), isTrue);
    expect(booked(BookingStatus.cancelled), isFalse);
    expect(booked(BookingStatus.expired), isFalse);
    expect(BookingSlotCalculator.isSlotBooked(
      slotKey: '4:00 PM',
      stadium: stadium,
      selectedDate: reportDate,
      existingBookings: [reservation('different-venue', date, venue: 'pitch-b')],
    ), isFalse);
  });

  test('outdated selected slot is discarded when a newer booking overlaps', () {
    final stadium = pitch();
    final slots = BookingSlotCalculator.generateDynamicTimeSlots(
      stadium: stadium, isArabic: false,
    );
    final start = BookingSlotCalculator.getSlotDateTime(
      slotKey: slots[0].key,
      stadium: stadium,
      selectedDate: reportDate,
    );
    final selected = BookingSlotCalculator.calculateNewSelectedSlots(
      slotKey: slots[1].key,
      currentSelectedSlots: [slots[0].key],
      timeSlots: slots,
      stadium: stadium,
      selectedDate: reportDate,
      existingBookings: [reservation('just-booked', start)],
    );
    expect(selected, [slots[1].key]);
  });

  test('UI distinguishes server loading/error/closure/full, no hardcoded scarcity', () {
    final section = File(
      'lib/features/player/widgets/booking/booking_slot_stream_section.dart',
    ).readAsStringSync();
    final card = File(
      'lib/features/player/widgets/booking/booking_slot_card.dart',
    ).readAsStringSync();
    final confirmation = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();
    expect(section, contains('BookingStreamFreshness.isAwaitingCurrentStream(snapshot)'));
    expect(section, contains('if (snapshot.hasError)'));
    expect(section, contains('if (!snapshot.hasData)'));
    expect(section, contains('if (widget.stadium.isBlocked)'));
    expect(section, contains('Venue schedule unavailable'));
    expect(section, contains('All slots are booked'));
    expect(section, contains('Venue temporarily closed'));
    expect(section, contains('No slots remaining'));
    expect(card, contains('onTap: ((isBooked || isClosed) || isPast) ? null : onTap'));
    expect(confirmation, contains('_selectedTimeSlots.clear();'));
    expect(section, isNot(contains('Only 2 slots left')));
    expect(section, isNot(contains('Limited-time offer')));
  });
}
