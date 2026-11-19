import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/providers/booking_provider.dart';
import 'package:vsp_application/core/repositories/booking_repository.dart';
import 'package:vsp_application/data/models.dart';

class _DelayedBookingReadsAndUpdates extends Fake implements BookingRepository {
  final read = Completer<Booking?>();
  bool manualUpdateResult = false;

  @override
  Future<Booking?> getBookingById(String bookingId) => read.future;

  @override
  Future<bool> updateManualBooking({
    required String bookingId,
    required String name,
    required String phone,
    required String notes,
    required bool isDepositPaid,
    required double depositPaid,
    required String paymentStatus,
  }) async => manualUpdateResult;

  @override
  Future<List<Booking>> getUserBookingsDirectly(String userId) async => [];

  @override
  Stream<List<Booking>> getUserBookings(String userId) =>
      const Stream<List<Booking>>.empty();

  @override
  Stream<List<Booking>> getOwnerBookings(
    String ownerId, {List<String>? stadiumIds}) =>
      const Stream<List<Booking>>.empty();
}

Booking _booking() {
  final start = DateTime.now().add(const Duration(days: 1));
  return Booking(
    id: 'owner-A-private-booking',
    stadiumId: 'stadium',
    stadiumName: 'Pitch',
    ownerId: 'owner-A',
    createdByUserId: 'user-A',
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    bookingType: BookingType.personal,
    isPrivate: true,
    rentBall: false,
    totalPrice: 200,
    paymentMethod: 'cash',
    status: BookingStatus.confirmed,
    createdAt: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pending booking-detail lookup cannot cross a new account session',
      () async {
    SharedPreferences.setMockInitialValues({});
    final backend = _DelayedBookingReadsAndUpdates();
    final provider = BookingProvider(repository: backend);
    addTearDown(provider.dispose);

    expect(await provider.loadUserBookings('user-A'), isTrue);
    final lookup = provider.getBookingById('owner-A-private-booking');
    expect(await provider.loadUserBookings('user-B'), isTrue);
    backend.read.complete(_booking());
    expect(await lookup, isNull);
    expect(provider.currentBooking, isNull);
    expect(provider.userBookings, isEmpty);
  });

  test('manual owner booking update reports explicit false result as an error',
      () async {
    SharedPreferences.setMockInitialValues({});
    final backend = _DelayedBookingReadsAndUpdates();
    final provider = BookingProvider(repository: backend);
    addTearDown(provider.dispose);

    expect(
      await provider.updateManualBooking(
        bookingId: 'booking-1',
        name: 'Captain',
        phone: '',
        notes: '',
        isDepositPaid: false,
        depositPaid: 0,
        paymentStatus: 'pending',
      ),
      isFalse,
    );
    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, contains('تعذر تحديث بيانات الحجز'));
  });
}
