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
  int fetchCalls = 0;

  @override
  Future<List<Booking>> fetchPublicMatches() {
    fetchCalls++;
    return ready.future;
  }
}

class _QueuedPublicMatches extends BookingMatchCoordinator {
  final requests = <Completer<List<Booking>>>[];

  @override
  Future<List<Booking>> fetchPublicMatches() {
    final completer = Completer<List<Booking>>();
    requests.add(completer);
    return completer.future;
  }
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
  test('initial public match load is single-flight and publishes its loading state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final feed = _DelayedPublicMatches();
    final provider = BookingProvider(
      repository: _InstantBookingRepo(),
      matchCoordinator: feed,
    );
    addTearDown(provider.dispose);

    final load = provider.fetchPublicMatches();
    expect(provider.isLoadingPublicMatches, isTrue);
    await provider.fetchPublicMatches();
    expect(feed.fetchCalls, 1);
    feed.ready.complete([_sampleMatch()]);
    await load;
    expect(provider.isLoadingPublicMatches, isFalse);
    expect(provider.publicMatches.single.id, 'old-public-match');
    expect(provider.errorMessage, isNull);
  });

  test('failed refresh clears stale match cards and supports explicit retry',
      () async {
    SharedPreferences.setMockInitialValues({});
    final feed = _QueuedPublicMatches();
    final provider = BookingProvider(
      repository: _InstantBookingRepo(),
      matchCoordinator: feed,
    );
    addTearDown(provider.dispose);

    final first = provider.fetchPublicMatches();
    feed.requests[0].complete([_sampleMatch()]);
    await first;
    expect(provider.publicMatches, hasLength(1));

    final refresh = provider.fetchPublicMatches(isRefresh: true);
    expect(provider.isLoadingPublicMatches, isTrue);
    expect(provider.publicMatches, isEmpty);
    feed.requests[1].completeError(StateError('PRIVATE_AUTH_TOKEN'));
    await refresh;
    expect(provider.isLoadingPublicMatches, isFalse);
    expect(provider.publicMatches, isEmpty);
    expect(provider.errorMessage, 'تعذر تحميل المباريات حالياً.');
    expect(provider.errorMessage, isNot(contains('PRIVATE_AUTH_TOKEN')));

    final retry = provider.fetchPublicMatches(isRefresh: true);
    feed.requests[2].complete([_sampleMatch()]);
    await retry;
    expect(provider.publicMatches.single.id, 'old-public-match');
    expect(provider.errorMessage, isNull);
  });

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
