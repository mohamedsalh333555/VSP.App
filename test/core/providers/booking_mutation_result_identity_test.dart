import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/providers/booking_provider.dart';
import 'package:vsp_application/core/providers/booking/booking_match_coordinator.dart';
import 'package:vsp_application/core/repositories/booking_repository.dart';
import 'package:vsp_application/data/models.dart';

class _PendingBookingRepository extends Fake implements BookingRepository {
  final creation = Completer<Booking>();

  @override
  Future<Booking> createBooking(BookingDraft draft, String userId) =>
      creation.future;

  @override
  Future<List<Booking>> getUserBookingsDirectly(String userId) async => [];

  @override
  Stream<List<Booking>> getUserBookings(String userId) =>
      const Stream<List<Booking>>.empty();

  @override
  Stream<List<Booking>> getOwnerBookings(
    String ownerId, {List<String>? stadiumIds}) =>
      const Stream<List<Booking>>.empty();

  @override
  Future<bool> respondToReschedule({
    required String bookingId,
    required bool accept,
  }) async => false;
}

class _RejectedMatchCoordinator extends BookingMatchCoordinator {
  @override
  Future<({bool success, String? error})> joinPublicMatch({
    required String bookingId,
    required String userId,
  }) async => (success: false, error: null);

  @override
  Future<({bool success, String? error})> leavePublicMatch({
    required String bookingId,
    required String userId,
  }) async => (success: false, error: null);
}

BookingDraft _draft() {
  final start = DateTime.now().add(const Duration(days: 1));
  return BookingDraft(
    stadiumId: 'stadium',
    stadiumName: 'Test pitch',
    ownerId: 'owner',
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    bookingType: BookingType.personal,
    isPrivate: true,
    rentBall: false,
    totalPrice: 150,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('old account successful booking RPC cannot return private booking to B',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _PendingBookingRepository();
    final provider = BookingProvider(repository: repo);
    addTearDown(provider.dispose);

    expect(await provider.loadUserBookings('user-A'), isTrue);
    final draft = _draft();
    provider.setDraft(draft);
    final pending = provider.createBookingFromDraft('user-A');
    expect(await provider.loadUserBookings('user-B'), isTrue);
    repo.creation.complete(Booking.fromDraft(
      id: 'old-user-A-booking',
      draft: draft,
      userId: 'user-A',
      status: BookingStatus.confirmed,
    ));
    expect(await pending, isNull);
    expect(provider.currentBooking, isNull);
    expect(provider.currentDraft, isNull);
    expect(provider.userBookings, isEmpty);
  });

  test('failed reschedule acceptance and public match actions show feedback',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = BookingProvider(
      repository: _PendingBookingRepository(),
      matchCoordinator: _RejectedMatchCoordinator(),
    );
    addTearDown(provider.dispose);

    expect(await provider.respondToReschedule(
      bookingId: 'booking-1', accept: true,
    ), isFalse);
    expect(provider.errorMessage, contains('تعذر قبول'));

    expect(await provider.joinPublicMatch('booking-1', 'user-A'), isFalse);
    expect(provider.errorMessage, contains('تعذر الانضمام'));

    expect(await provider.leavePublicMatch('booking-1', 'user-A'), isFalse);
    expect(provider.errorMessage, contains('تعذر مغادرة'));
  });
}
