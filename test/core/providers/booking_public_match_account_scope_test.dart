import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/providers/booking_provider.dart';
import 'package:vsp_application/core/providers/booking/booking_match_coordinator.dart';
import 'package:vsp_application/core/repositories/booking_repository.dart';
import 'package:vsp_application/data/models.dart';

class _InstantBookingRepo extends Fake implements BookingRepository {
  @override
  Future<List<Booking>> getUserBookingsDirectly(String userId) async => [];

  @override
  Stream<List<Booking>> getUserBookings(String userId) =>
      const Stream<List<Booking>>.empty();

  @override
  Stream<List<Booking>> getOwnerBookings(String ownerId, {List<String>? stadiumIds}) =>
      const Stream<List<Booking>>.empty();
}

class _DelayedPublicMatches extends BookingMatchCoordinator {
  final ready = Completer<List<Booking>>();

  @override
  Future<List<Booking>> fetchPublicMatches() => ready.future;
}

Booking _sampleMatch() {
  final start = DateTime.now().add(const Duration(hours: 2));
  return Booking(
    id: 'old-public-match',
    stadiumId: 'stadium',
    stadiumName: 'Example',
    ownerId: 'owner-A',
    createdByUserId: 'user-A',
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    bookingType: BookingType.openJoin,
    isPrivate: false,
    rentBall: false,
    totalPrice: 200,
    paymentMethod: 'cash',
    status: BookingStatus.confirmed,
    createdAt: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('late public match snapshot cannot repopulate a new account', () async {
    SharedPreferences.setMockInitialValues({});
    final matches = _DelayedPublicMatches();
    final provider = BookingProvider(
      repository: _InstantBookingRepo(),
      matchCoordinator: matches,
    );
    addTearDown(provider.dispose);

    expect(await provider.loadUserBookings('user-A'), isTrue);
    final pendingMatches = provider.fetchPublicMatches(isRefresh: true);
    expect(provider.isLoadingPublicMatches, isTrue);

    expect(await provider.loadUserBookings('user-B'), isTrue);
    expect(provider.isLoadingPublicMatches, isFalse);
    expect(provider.publicMatches, isEmpty);

    matches.ready.complete([_sampleMatch()]);
    await pendingMatches;
    expect(provider.publicMatches, isEmpty);
    expect(provider.errorMessage, isNull);
  });
}
