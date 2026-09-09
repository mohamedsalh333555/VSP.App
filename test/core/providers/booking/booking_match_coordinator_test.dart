import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/providers/booking/booking_match_coordinator.dart';
import 'package:vsp_application/core/repositories/match_repository.dart';
import 'package:vsp_application/data/models.dart';

class FakeMatchRepository implements MatchRepository {
  bool joinResult = true;
  bool leaveResult = true;
  Exception? errorToThrow;

  @override
  Future<bool> joinPublicMatch(String matchId, String userId) async {
    if (errorToThrow != null) throw errorToThrow!;
    return joinResult;
  }

  @override
  Future<bool> leavePublicMatch(String matchId, String userId) async {
    if (errorToThrow != null) throw errorToThrow!;
    return leaveResult;
  }

  @override
  Stream<List<Booking>> getPublicMatches() => Stream.value([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BookingMatchCoordinator Tests', () {
    late FakeMatchRepository fakeRepo;
    late BookingMatchCoordinator coordinator;

    setUp(() {
      fakeRepo = FakeMatchRepository();
      coordinator = BookingMatchCoordinator(matchRepository: fakeRepo);
    });

    test('joinPublicMatch returns success on clean response', () async {
      final res = await coordinator.joinPublicMatch(bookingId: 'b1', userId: 'u1');
      expect(res.success, isTrue);
      expect(res.error, isNull);
    });

    test('joinPublicMatch handles error and returns formatted message', () async {
      fakeRepo.errorToThrow = Exception('Failed to join match');
      final res = await coordinator.joinPublicMatch(bookingId: 'b1', userId: 'u1');
      expect(res.success, isFalse);
      expect(res.error, isNotNull);
    });

    test('leavePublicMatch returns success on clean response', () async {
      final res = await coordinator.leavePublicMatch(bookingId: 'b1', userId: 'u1');
      expect(res.success, isTrue);
      expect(res.error, isNull);
    });

    test('leavePublicMatch handles error and returns error message', () async {
      fakeRepo.errorToThrow = Exception('Network error');
      final res = await coordinator.leavePublicMatch(bookingId: 'b1', userId: 'u1');
      expect(res.success, isFalse);
      expect(res.error, contains('Network error'));
    });

    test('fetchPublicMatches returns list from stream', () async {
      final matches = await coordinator.fetchPublicMatches();
      expect(matches, isEmpty);
    });
  });
}
