import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/providers/booking_provider.dart';
import 'package:vsp_application/core/repositories/booking_repository.dart';
import 'package:vsp_application/data/models.dart';

class _DelayedBookingRepository extends Fake implements BookingRepository {
  final Map<String, Completer<List<Booking>>> responses;
  final Map<String, Completer<void>> started;
  final Completer<bool>? cancellation;

  _DelayedBookingRepository(this.responses, this.started, {this.cancellation});

  @override
  Future<bool> cancelBooking(String bookingId) =>
      cancellation?.future ?? Future<bool>.value(false);

  @override
  Future<Booking?> getBookingByIdStrict(String bookingId) async =>
      _fixtureBooking('user-A');

  @override
  Future<List<Booking>> getUserBookingsDirectly(String userId) {
    started[userId]!.complete();
    return responses[userId]!.future;
  }

  @override
  Stream<List<Booking>> getUserBookings(String userId) =>
      const Stream<List<Booking>>.empty();

  @override
  Stream<List<Booking>> getOwnerBookings(
    String ownerId, {
    List<String>? stadiumIds,
  }) =>
      const Stream<List<Booking>>.empty();
}

Booking _fixtureBooking(String userId) {
  final start = DateTime.now().add(const Duration(days: 2));
  return Booking(
    id: 'booking-$userId',
    stadiumId: 'pitch-1',
    stadiumName: 'Aswan pitch',
    ownerId: 'venue-owner',
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    bookingType: BookingType.personal,
    isPrivate: true,
    rentBall: false,
    totalPrice: 100,
    paymentMethod: 'cash',
    status: BookingStatus.confirmed,
    createdByUserId: userId,
    createdAt: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('disposing provider invalidates a pending player snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final responses = <String, Completer<List<Booking>>>{
      'user-A': Completer<List<Booking>>(),
    };
    final started = <String, Completer<void>>{
      'user-A': Completer<void>(),
    };
    final provider = BookingProvider(
      repository: _DelayedBookingRepository(responses, started),
    );
    final pending = provider.loadUserBookings('user-A');
    await started['user-A']!.future.timeout(const Duration(seconds: 5));
    provider.dispose();
    responses['user-A']!.complete([_fixtureBooking('user-A')]);
    expect(await pending, isFalse);
  });

  test('delayed user A bookings never replace user B after account switch',
      () async {
    SharedPreferences.setMockInitialValues({});
    final responses = <String, Completer<List<Booking>>>{
      'user-A': Completer<List<Booking>>(),
      'user-B': Completer<List<Booking>>(),
    };
    final started = <String, Completer<void>>{
      'user-A': Completer<void>(),
      'user-B': Completer<void>(),
    };
    final repo = _DelayedBookingRepository(responses, started);
    final provider = BookingProvider(repository: repo);
    addTearDown(provider.dispose);

    final oldLoad = provider.loadUserBookings('user-A');
    await started['user-A']!.future.timeout(const Duration(seconds: 5));
    final newLoad = provider.loadUserBookings('user-B');
    await started['user-B']!.future.timeout(const Duration(seconds: 5));

    responses['user-B']!.complete([_fixtureBooking('user-B')]);
    expect(await newLoad, isTrue);
    expect(provider.userBookings.map((b) => b.createdByUserId), ['user-B']);
    // A is still pending: its spinner must not be attributed to B.
    expect(provider.isLoadingUserBookings, isFalse);

    responses['user-A']!.complete([_fixtureBooking('user-A')]);
    expect(await oldLoad, isFalse);
    expect(provider.userBookings.map((b) => b.createdByUserId), ['user-B']);
  });

  test('late cancellation from account A cannot insert a booking into B',
      () async {
    SharedPreferences.setMockInitialValues({});
    final responses = <String, Completer<List<Booking>>>{
      'user-A': Completer<List<Booking>>(),
      'user-B': Completer<List<Booking>>(),
    };
    final started = <String, Completer<void>>{
      'user-A': Completer<void>(),
      'user-B': Completer<void>(),
    };
    final cancellation = Completer<bool>();
    final provider = BookingProvider(
      repository: _DelayedBookingRepository(
        responses, started, cancellation: cancellation,
      ),
    );
    addTearDown(provider.dispose);

    final loadA = provider.loadUserBookings('user-A');
    await started['user-A']!.future.timeout(const Duration(seconds: 5));
    responses['user-A']!.complete([_fixtureBooking('user-A')]);
    expect(await loadA, isTrue);

    final oldCancel = provider.cancelBooking('booking-user-A');
    final loadB = provider.loadUserBookings('user-B');
    await started['user-B']!.future.timeout(const Duration(seconds: 5));
    responses['user-B']!.complete([_fixtureBooking('user-B')]);
    expect(await loadB, isTrue);
    expect(provider.userBookings.single.createdByUserId, 'user-B');

    cancellation.complete(true);
    expect(await oldCancel, isTrue);
    expect(provider.userBookings, hasLength(1));
    expect(provider.userBookings.single.createdByUserId, 'user-B');
    expect(provider.errorMessage, isNull);
  });

  test('switch to owner clears the previous player bookings immediately',
      () async {
    SharedPreferences.setMockInitialValues({});
    final responses = <String, Completer<List<Booking>>>{
      'player': Completer<List<Booking>>(),
    };
    final started = <String, Completer<void>>{
      'player': Completer<void>(),
    };
    final provider = BookingProvider(
      repository: _DelayedBookingRepository(responses, started),
    );
    addTearDown(provider.dispose);

    final load = provider.loadUserBookings('player');
    await started['player']!.future.timeout(const Duration(seconds: 5));
    responses['player']!.complete([_fixtureBooking('player')]);
    expect(await load, isTrue);
    expect(provider.userBookings, hasLength(1));

    final nextScope = provider.loadOwnerBookings('different-owner');
    expect(provider.userBookings, isEmpty);
    expect(provider.isLoadingUserBookings, isFalse);
    await nextScope;
    expect(provider.userBookings, isEmpty);
    expect(provider.isLoadingOwnerBookings, isFalse);
  });
}
