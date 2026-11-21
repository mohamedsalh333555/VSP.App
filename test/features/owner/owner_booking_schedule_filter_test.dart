import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/owner/widgets/bookings/owner_booking_schedule_filter.dart';

Booking fixture(
  String id,
  DateTime start, {
  String venue = 'pitch-a',
  BookingStatus status = BookingStatus.confirmed,
  DateTime? operationalDate,
}) => Booking(
  id: id,
  ownerId: 'owner-fixture',
  stadiumId: venue,
  stadiumName: 'Synthetic Pitch',
  startTime: start,
  endTime: start.add(const Duration(hours: 1)),
  operationalDate: operationalDate,
  bookingType: BookingType.personal,
  isPrivate: true,
  rentBall: false,
  totalPrice: 200,
  paymentMethod: 'cash',
  status: status,
  createdByUserId: 'fixture-player',
  createdAt: DateTime(2026, 11, 18),
);

void main() {
  final day = DateTime(2026, 11, 18);
  final nextDay = DateTime(2026, 11, 19);

  test('shows only selected venue and operational day, never cancelled rows', () {
    final data = [
      fixture('right', DateTime(2026, 11, 18, 19), venue: ' PITCH-A '),
      fixture('different-venue', DateTime(2026, 11, 18, 20), venue: 'pitch-b'),
      fixture('different-day', DateTime(2026, 11, 20, 19)),
      fixture('cancelled', DateTime(2026, 11, 18, 21),
          status: BookingStatus.cancelled),
    ];
    final result = OwnerBookingScheduleFilter.select(
      bookings: data,
      stadiumId: 'pitch-a',
      operationalDay: day,
      openingHour: 16,
    );
    expect(result.map((b) => b.id), ['right']);
  });

  test('booking after midnight belongs to the previous overnight shift', () {
    final data = [
      fixture('late-night', DateTime(2026, 11, 18, 23, 30)),
      fixture('after-midnight', DateTime(2026, 11, 19, 1, 0)),
      fixture('next-shift', DateTime(2026, 11, 19, 23, 0)),
    ];
    final first = OwnerBookingScheduleFilter.select(
      bookings: data, stadiumId: 'pitch-a',
      operationalDay: day, openingHour: 22,
    );
    expect(first.map((b) => b.id), ['late-night', 'after-midnight']);
    final next = OwnerBookingScheduleFilter.select(
      bookings: data, stadiumId: 'pitch-a',
      operationalDay: nextDay, openingHour: 22,
    );
    expect(next.map((b) => b.id), ['next-shift']);
  });

  test('server-stored operational day wins over guessed shift date', () {
    final shifted = fixture(
      'server-day', DateTime(2026, 11, 19, 1),
      operationalDate: day,
    );
    expect(OwnerBookingScheduleFilter.select(
      bookings: [shifted], stadiumId: 'pitch-a',
      operationalDay: day, openingHour: 8,
    ).map((b) => b.id), ['server-day']);
    expect(OwnerBookingScheduleFilter.select(
      bookings: [shifted], stadiumId: 'pitch-a',
      operationalDay: nextDay, openingHour: 8,
    ), isEmpty);
  });

  test('empty venue key or invalid opening hour never exposes all bookings', () {
    final data = [fixture('private', DateTime(2026, 11, 18, 19))];
    for (final id in ['', '  ']) {
      expect(OwnerBookingScheduleFilter.select(
        bookings: data, stadiumId: id,
        operationalDay: day, openingHour: 16,
      ), isEmpty);
    }
    for (final hour in [-1, 24]) {
      expect(OwnerBookingScheduleFilter.select(
        bookings: data, stadiumId: 'pitch-a',
        operationalDay: day, openingHour: hour,
      ), isEmpty);
    }
  });

  test('owner UI uses scoped feed after owner-role and loading gates', () {
    final src = File(
      'lib/features/owner/screens/owner_bookings_screen.dart',
    ).readAsStringSync();
    expect(src, contains('if (!auth.isOwner || auth.currentUser == null)'));
    expect(src, contains('if (!bookingProvider.hasLoadedOwnerBookings)'));
    expect(src, contains('OwnerBookingScheduleFilter.select('));
    expect(src, contains('bookings: bookingProvider.userBookings,'));
    expect(src, contains('stadiumId: selectedStadium.id,'));
    expect(src, contains('operationalDay: selectedDateOnly,'));
    expect(src, contains('openingHour: startH,'));
  });
}
