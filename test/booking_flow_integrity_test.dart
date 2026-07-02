import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/core/repositories/booking_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Booking Flow Integrity Tests
// Covers: BookingDraft lifecycle, branching, challenge integrity, classification,
//         player count integrity, and payment method defaults.
// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('A. BookingDraft field survival through Booking.fromDraft()', () {
    test('Personal cash booking preserves all required fields', () {
      final now = DateTime(2026, 3, 20, 18, 0);
      final draft = BookingDraft(
        stadiumId: 'stad_abc',
        stadiumName: 'VSP Arena',
        stadiumImageUrl: 'https://example.com/image.jpg',
        ownerId: 'owner_xyz',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: true,
        totalPrice: 200.0,
        paymentMethod: 'cash',
        currentPlayers: 1,
        totalFieldCapacity: 10,
      );

      final booking = Booking.fromDraft(
        id: 'bk_001',
        draft: draft,
        userId: 'user_123',
        status: BookingStatus.confirmed,
      );

      // All vital fields must survive
      expect(booking.stadiumId, 'stad_abc');
      expect(booking.stadiumName, 'VSP Arena');
      expect(booking.stadiumImageUrl, 'https://example.com/image.jpg');
      expect(booking.ownerId, 'owner_xyz');
      expect(booking.startTime, now);
      expect(booking.endTime, now.add(const Duration(hours: 1)));
      expect(booking.bookingType, BookingType.personal);
      expect(booking.isPrivate, true);
      expect(booking.rentBall, true);
      expect(booking.totalPrice, 200.0);
      expect(booking.paymentMethod, 'cash');
      expect(booking.currentPlayers, 1);
      expect(booking.maxPlayers, 10);
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.createdByUserId, 'user_123');
      expect(booking.joinedUserIds, contains('user_123'));
    });

    test('Cash-only MVP: default paymentMethod is cash when not specified', () {
      final draft = BookingDraft(
        stadiumId: 's1',
        stadiumName: 'Test',
        ownerId: 'o1',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 100,
        // paymentMethod is intentionally not set
      );

      final booking = Booking.fromDraft(
        id: 'bk_002',
        draft: draft,
        userId: 'u1',
        status: BookingStatus.confirmed,
      );

      expect(booking.paymentMethod, 'cash',
          reason: 'Cash-only MVP: must never default to card');
    });
  });

  group('B. Challenge booking field integrity', () {
    test('Challenge booking preserves opponentTeamId and opponentTeamName', () {
      final draft = BookingDraft(
        stadiumId: 's1',
        stadiumName: 'Test',
        ownerId: 'o1',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        bookingType: BookingType.challenge,
        playerTeamId: 'my_team_1',
        playerTeamName: 'Red Eagles',
        opponentTeamId: 'opp_team_2',
        opponentTeamName: 'Blue Lions',
        isPrivate: false,
        rentBall: false,
        totalPrice: 300,
      );

      final booking = Booking.fromDraft(
        id: 'bk_003',
        draft: draft,
        userId: 'u1',
        status: BookingStatus.confirmed,
      );

      expect(booking.bookingType, BookingType.challenge);
      expect(booking.playerTeamId, 'my_team_1');
      expect(booking.playerTeamName, 'Red Eagles');
      expect(booking.opponentTeamId, 'opp_team_2');
      expect(booking.opponentTeamName, 'Blue Lions');
    });

    test('fromFirestore: opponentTeam fields are only read for challenge type', () {
      final data = {
        'stadiumId': 's1',
        'stadiumName': 'Test',
        'ownerId': 'o1',
        'startTime': Timestamp.fromDate(DateTime(2026, 4, 1, 10, 0)),
        'endTime': Timestamp.fromDate(DateTime(2026, 4, 1, 11, 0)),
        // bookingType is personal - opponent data should be null even if present
        'bookingType': 'personal',
        'opponentTeamId': 'ghost_team',
        'opponentTeamName': 'Should Be Null',
        'isPrivate': true,
        'rentBall': false,
        'totalPrice': 100,
        'currency': 'EGP',
        'paymentMethod': 'cash',
        'status': 'confirmed',
        'createdByUserId': 'u1',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'matchResultStatus': 'noResult',
        'currentPlayers': 1,
        'maxPlayers': 10,
        'joinedUserIds': [],
      };

      final booking = Booking.fromFirestore(data, 'bk_004');

      expect(booking.bookingType, BookingType.personal);
      // For non-challenge bookings, opponent data must be stripped
      expect(booking.opponentTeamId, isNull);
      expect(booking.opponentTeamName, isNull);
    });
  });

  group('C. Public/Team booking player count integrity', () {
    test('currentPlayers and maxPlayers are stored correctly', () {
      final draft = BookingDraft(
        stadiumId: 's1',
        stadiumName: 'Open Pitch',
        ownerId: 'o1',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        bookingType: BookingType.team,
        isPrivate: false,
        rentBall: false,
        totalPrice: 150,
        currentPlayers: 3,
        totalFieldCapacity: 10,
      );

      final booking = Booking.fromDraft(
        id: 'bk_005',
        draft: draft,
        userId: 'u1',
        status: BookingStatus.confirmed,
      );

      expect(booking.currentPlayers, 3,
          reason: 'currentPlayers from draft must survive');
      expect(booking.maxPlayers, 10,
          reason: 'maxPlayers must never be zero or default: 0');
      expect(booking.maxPlayers, greaterThan(0),
          reason: 'maxPlayers must always be > 0');
      expect(booking.bookingType, BookingType.team);
      expect(booking.isPrivate, false);
    });

    test('maxPlayers defaults gracefully when not set in draft', () {
      final draft = BookingDraft(
        stadiumId: 's1',
        stadiumName: 'Test',
        ownerId: 'o1',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        bookingType: BookingType.team,
        isPrivate: false,
        rentBall: false,
        totalPrice: 100,
        // currentPlayers and maxPlayers use defaults: 1 and 10
      );

      expect(draft.maxPlayers, greaterThan(0),
          reason: 'Default maxPlayers must be > 0 (currently 10)');
      expect(draft.currentPlayers, 1);
    });
  });

  group('D. Booking classification (upcoming vs history)', () {
    final now = DateTime.now();

    Booking makeBooking({
      required String id,
      required DateTime startTime,
      required DateTime endTime,
      required BookingStatus status,
    }) {
      return Booking(
        id: id,
        stadiumId: 's1',
        stadiumName: 'Test',
        ownerId: 'o1',
        startTime: startTime,
        endTime: endTime,
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 100,
        paymentMethod: 'cash',
        status: status,
        createdByUserId: 'u1',
        createdAt: DateTime.now(),
      );
    }

    test('Future confirmed booking is classified as upcoming', () {
      final futureBooking = makeBooking(
        id: 'upcoming_1',
        startTime: now.add(const Duration(days: 2)),
        endTime: now.add(const Duration(days: 2, hours: 1)),
        status: BookingStatus.confirmed,
      );

      final bookings = [futureBooking];
      final upcoming = bookings
          .where((b) =>
              b.status == BookingStatus.confirmed && b.endTime.isAfter(now))
          .toList();
      final history = bookings
          .where((b) =>
              b.status == BookingStatus.completed ||
              b.status == BookingStatus.cancelled ||
              (b.status == BookingStatus.confirmed && b.endTime.isBefore(now)))
          .toList();

      expect(upcoming.length, 1);
      expect(history.length, 0);
    });

    test('Past confirmed booking is classified as history', () {
      final pastBooking = makeBooking(
        id: 'history_1',
        startTime: now.subtract(const Duration(days: 5, hours: 2)),
        endTime: now.subtract(const Duration(days: 5, hours: 1)),
        status: BookingStatus.confirmed, // still "confirmed" but endTime is past
      );

      final bookings = [pastBooking];
      final upcoming = bookings
          .where((b) =>
              b.status == BookingStatus.confirmed && b.endTime.isAfter(now))
          .toList();
      final history = bookings
          .where((b) =>
              b.status == BookingStatus.completed ||
              b.status == BookingStatus.cancelled ||
              (b.status == BookingStatus.confirmed && b.endTime.isBefore(now)))
          .toList();

      expect(upcoming.length, 0);
      expect(history.length, 1);
    });

    test('Completed booking is always classified as history', () {
      final completedBooking = makeBooking(
        id: 'completed_1',
        startTime: now.subtract(const Duration(days: 1, hours: 2)),
        endTime: now.subtract(const Duration(days: 1, hours: 1)),
        status: BookingStatus.completed,
      );

      final bookings = [completedBooking];
      final upcoming = bookings
          .where((b) =>
              b.status == BookingStatus.confirmed && b.endTime.isAfter(now))
          .toList();
      final history = bookings
          .where((b) =>
              b.status == BookingStatus.completed ||
              b.status == BookingStatus.cancelled ||
              (b.status == BookingStatus.confirmed && b.endTime.isBefore(now)))
          .toList();

      expect(upcoming.length, 0);
      expect(history.length, 1);
    });

    test('Mixed bookings classify correctly', () {
      final futurBooking = makeBooking(
        id: 'mix_upcoming',
        startTime: now.add(const Duration(days: 1)),
        endTime: now.add(const Duration(days: 1, hours: 1)),
        status: BookingStatus.confirmed,
      );
      final pastConfirmed = makeBooking(
        id: 'mix_past',
        startTime: now.subtract(const Duration(hours: 3)),
        endTime: now.subtract(const Duration(hours: 2)),
        status: BookingStatus.confirmed,
      );
      final cancelled = makeBooking(
        id: 'mix_cancelled',
        startTime: now.add(const Duration(days: 3)),
        endTime: now.add(const Duration(days: 3, hours: 1)),
        status: BookingStatus.cancelled,
      );

      final bookings = [futurBooking, pastConfirmed, cancelled];
      final upcoming = bookings
          .where((b) =>
              b.status == BookingStatus.confirmed && b.endTime.isAfter(now))
          .toList();
      final history = bookings
          .where((b) =>
              b.status == BookingStatus.completed ||
              b.status == BookingStatus.cancelled ||
              (b.status == BookingStatus.confirmed && b.endTime.isBefore(now)))
          .toList();

      expect(upcoming.length, 1, reason: 'Only the future confirmed booking');
      expect(upcoming.first.id, 'mix_upcoming');
      expect(history.length, 2, reason: 'Past + cancelled both go to history');
    });
  });

  group('E. Double-booking overlap detection', () {
    test('Overlapping time slots are detected correctly', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final baseTime = DateTime(2026, 5, 1, 18, 0); // 6 PM

      // Existing confirmed booking: 6 PM - 7 PM
      await fakeFirestore.collection('bookings').add({
        'stadiumId': 'stad_1',
        'startTime': Timestamp.fromDate(baseTime),
        'endTime': Timestamp.fromDate(baseTime.add(const Duration(hours: 1))),
        'status': 'confirmed',
      });

      // New draft: 6:30 PM - 7:30 PM (overlap!)
      final newStart = baseTime.add(const Duration(minutes: 30));
      final newEnd = baseTime.add(const Duration(minutes: 90));

      final snapshot = await fakeFirestore
          .collection('bookings')
          .where('stadiumId', isEqualTo: 'stad_1')
          .get();

      bool isOverlapping = false;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'cancelled') continue;
        final bStart = (data['startTime'] as Timestamp).toDate();
        final bEnd = (data['endTime'] as Timestamp).toDate();
        if (newStart.isBefore(bEnd) && newEnd.isAfter(bStart)) {
          isOverlapping = true;
        }
      }

      expect(isOverlapping, true,
          reason: 'Overlapping booking must be prevented');
    });

    test('Non-overlapping booking is allowed', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final baseTime = DateTime(2026, 5, 1, 18, 0); // 6 PM

      // Existing booking: 6 PM - 7 PM
      await fakeFirestore.collection('bookings').add({
        'stadiumId': 'stad_1',
        'startTime': Timestamp.fromDate(baseTime),
        'endTime': Timestamp.fromDate(baseTime.add(const Duration(hours: 1))),
        'status': 'confirmed',
      });

      // New draft: 7 PM - 8 PM (no overlap)
      final newStart = baseTime.add(const Duration(hours: 1));
      final newEnd = baseTime.add(const Duration(hours: 2));

      final snapshot = await fakeFirestore
          .collection('bookings')
          .where('stadiumId', isEqualTo: 'stad_1')
          .get();

      bool isOverlapping = false;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'cancelled') continue;
        final bStart = (data['startTime'] as Timestamp).toDate();
        final bEnd = (data['endTime'] as Timestamp).toDate();
        if (newStart.isBefore(bEnd) && newEnd.isAfter(bStart)) {
          isOverlapping = true;
        }
      }

      expect(isOverlapping, false,
          reason: 'Adjacent (non-overlapping) booking must be allowed');
    });
  });

  group('F. MockBookingRepository creates booking correctly', () {
    test('createBooking via MockRepo produces a confirmed booking', () async {
      final repo = MockBookingRepository();
      final draft = BookingDraft(
        stadiumId: 'stad_1',
        stadiumName: 'Arena Test',
        ownerId: 'owner_1',
        startTime: DateTime(2026, 6, 1, 17, 0),
        endTime: DateTime(2026, 6, 1, 18, 0),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 150,
        paymentMethod: 'cash',
      );

      final booking = await repo.createBooking(draft, 'user_abc');

      expect(booking.stadiumId, 'stad_1');
      expect(booking.ownerId, 'owner_1');
      expect(booking.status, BookingStatus.confirmed,
          reason: 'Cash-only MVP must auto-confirm');
      expect(booking.paymentMethod, 'cash');
      expect(booking.createdByUserId, 'user_abc');
      expect(booking.totalPrice, 150.0);
    });

    test('Owner can see their booking via getOwnerBookings', () async {
      final repo = MockBookingRepository();
      final draft = BookingDraft(
        stadiumId: 's1',
        stadiumName: 'My Stadium',
        ownerId: 'owner_A',
        startTime: DateTime(2026, 7, 1, 10, 0),
        endTime: DateTime(2026, 7, 1, 11, 0),
        bookingType: BookingType.personal,
        isPrivate: false,
        rentBall: false,
        totalPrice: 100,
      );

      await repo.createBooking(draft, 'player_1');

      final ownerBookings = await repo.getOwnerBookings('owner_A').first;
      expect(ownerBookings.length, 1);
      expect(ownerBookings.first.ownerId, 'owner_A');

      // Another owner must NOT see it
      final otherOwnerBookings =
          await repo.getOwnerBookings('owner_B').first;
      expect(otherOwnerBookings.length, 0);
    });
  });
}
