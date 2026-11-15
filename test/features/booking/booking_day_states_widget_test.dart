import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/booking_provider.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_calculator.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_card.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_stream_section.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class _Availability extends Fake implements BookingProvider {
  Stream<List<Booking>> stream = Stream.value(<Booking>[]);

  @override
  Stream<List<Booking>> getBookingsForStadium(String id, DateTime date) => stream;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

Stadium _venue({DateTime? maintenanceUntil}) => Stadium(
      id: 'pitch-1',
      name: 'Nile Pitch',
      location: 'Aswan',
      imageUrl: '',
      type: 'Football',
      size: '5 VS 5',
      baths: 0,
      cafeteria: 0,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 200,
      area: 'Aswan',
      isVerified: true,
      openingTime: '08:00 AM',
      closingTime: '12:00 AM',
      maintenanceUntil: maintenanceUntil,
    );

final _slot = TimeSlotItem(
  startTime: '4:00 PM',
  endTime: '4:30 PM',
  key: '4:00 PM',
  startMinutes: 960,
);

Widget _host(
  _Availability availability, {
  required DateTime date,
  required Stadium stadium,
  List<TimeSlotItem>? slots,
}) => ChangeNotifierProvider<BookingProvider>.value(
      value: availability,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookingSlotStreamSection(
              key: ObjectKey(availability),
              stadiumId: stadium.id,
              stadium: stadium,
              selectedDate: date,
              viewerUserId: 'player-1',
              timeSlots: slots ?? [_slot],
              selectedTimeSlots: const [],
              onSlotTap: (_, _) {},
            ),
          ),
        ),
      ),
    );

Booking _confirmedSlot(Stadium stadium, DateTime date) {
  final start = BookingSlotCalculator.getSlotDateTime(
    slotKey: _slot.key,
    stadium: stadium,
    selectedDate: date,
  );
  return Booking(
    id: 'booking-1',
    ownerId: 'owner-1',
    stadiumId: stadium.id,
    stadiumName: stadium.name,
    startTime: start,
    endTime: start.add(const Duration(minutes: 30)),
    bookingType: BookingType.personal,
    isPrivate: true,
    rentBall: false,
    createdByUserId: 'player-2',
    totalPrice: 100,
    status: BookingStatus.confirmed,
    paymentStatus: 'paid',
    paymentMethod: 'cash',
    createdAt: DateTime.now(),
  );
}

void main() {
  testWidgets('loading and retry distinguish transport failure from free slots',
      (tester) async {
    final availability = _Availability();
    final pending = StreamController<List<Booking>>();
    availability.stream = pending.stream;
    final date = DateTime.now().add(const Duration(days: 3));
    await tester.pumpWidget(_host(availability, date: date, stadium: _venue()));
    expect(find.text('Loading availability'), findsOneWidget);
    pending.addError(StateError('offline'));
    await tester.pump();
    expect(find.text('Could not load availability'), findsOneWidget);
    unawaited(pending.close());

    availability.stream = Stream.value(<Booking>[]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(BookingSlotCard), findsOneWidget);
  });

  testWidgets('closure, full booking, past day and missing hours have distinct states',
      (tester) async {
    final availability = _Availability();
    final date = DateTime.now().add(const Duration(days: 3));
    await tester.pumpWidget(_host(
      availability,
      date: date,
      stadium: _venue(maintenanceUntil: DateTime.now().add(const Duration(days: 4))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Venue temporarily closed'), findsOneWidget);

    final stadium = _venue();
    final bookedAvailability = _Availability()
      ..stream = Stream.value([_confirmedSlot(stadium, date)]);
    await tester.pumpWidget(_host(
      bookedAvailability,
      date: date,
      stadium: stadium,
    ));
    await tester.pumpAndSettle();
    expect(find.text('All slots are booked'), findsOneWidget);

    await tester.pumpWidget(_host(
      _Availability(),
      date: DateTime.now().subtract(const Duration(days: 2)),
      stadium: stadium,
    ));
    await tester.pumpAndSettle();
    expect(find.text('All slots have passed'), findsOneWidget);

    await tester.pumpWidget(_host(
      _Availability(),
      date: date,
      stadium: stadium,
      slots: const [],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Venue schedule unavailable'), findsOneWidget);
  });
}
