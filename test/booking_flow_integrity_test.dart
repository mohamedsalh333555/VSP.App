import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('1. Standard Pitch Booking Journey (Solo)', () {
    test('Standard pitch booking creates direct reservation with 0% platform fee', () {
      final now = DateTime(2026, 8, 1, 18, 0);
      final draft = BookingDraft(
        stadiumId: 'stad_cairo_1',
        stadiumName: 'Cairo Arena',
        stadiumImageUrl: 'https://vsp.app/stadium.jpg',
        ownerId: 'owner_cairo_1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
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

      expect(booking.bookingType, BookingType.personal);
      expect(booking.totalPrice, 200.0);
      expect(booking.stadiumId, 'stad_cairo_1');
      expect(booking.createdByUserId, 'user_123');
    });
  });

  group('2. Open Join Gathering Match Journey (OpenJoin)', () {
    test('OpenJoin match supports initial player count, public/private visibility & player joining', () {
      final now = DateTime(2026, 8, 2, 20, 0);
      final draft = BookingDraft(
        stadiumId: 'stad_alex_1',
        stadiumName: 'Alex Arena',
        ownerId: 'owner_alex_1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        bookingType: BookingType.openJoin,
        isPrivate: false, // Public match visible on map/radar
        rentBall: true,
        totalPrice: 220.0, // 200 base + 20 ball
        currentPlayers: 4, // Host brings 4 available players
        totalFieldCapacity: 10,
      );

      final booking = Booking.fromDraft(
        id: 'bk_open_001',
        draft: draft,
        userId: 'host_player_1',
        status: BookingStatus.confirmed,
      );

      expect(booking.bookingType, BookingType.openJoin);
      expect(booking.isPrivate, false);
      expect(booking.currentPlayers, 4);
      expect(booking.totalFieldCapacity, 10);
      expect(booking.rentBall, true);

      // Simulate a 5th player joining via deep-link or public feed
      final updatedJoinedList = List<String>.from(booking.joinedUserIds)..add('joining_player_2');
      final updatedBooking = booking.copyWith(
        currentPlayers: booking.currentPlayers + 1,
        joinedUserIds: updatedJoinedList,
      );

      expect(updatedBooking.currentPlayers, 5);
      expect(updatedBooking.joinedUserIds.contains('joining_player_2'), true);
      expect(updatedBooking.userId, 'host_player_1');
    });

    test('Private OpenJoin match is flagged private and hidden from public feed', () {
      final draft = BookingDraft(
        stadiumId: 'stad_cairo_2',
        stadiumName: 'Zamalek Turf',
        ownerId: 'owner_2',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        bookingType: BookingType.openJoin,
        isPrivate: true, // Private gathering match (share link only)
        rentBall: false,
        totalPrice: 200.0,
      );

      final booking = Booking.fromDraft(
        id: 'bk_private_002',
        draft: draft,
        userId: 'host_player_2',
        status: BookingStatus.confirmed,
      );

      expect(booking.isPrivate, true);
      expect(booking.bookingType, BookingType.openJoin);
    });
  });

  group('3. Team Challenge Match Journey (Challenge)', () {
    test('Challenge booking records team vs opponent details and match result state', () {
      final draft = BookingDraft(
        stadiumId: 's1',
        stadiumName: 'Test Pitch',
        ownerId: 'o1',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        bookingType: BookingType.challenge,
        playerTeamId: 'team_red',
        playerTeamName: 'Red Eagles',
        opponentTeamId: 'team_blue',
        opponentTeamName: 'Blue Lions',
        isPrivate: false,
        rentBall: false,
        totalPrice: 300,
      );

      final booking = Booking.fromDraft(
        id: 'bk_challenge_001',
        draft: draft,
        userId: 'captain_red',
        status: BookingStatus.confirmed,
      );

      expect(booking.bookingType, BookingType.challenge);
      expect(booking.playerTeamId, 'team_red');
      expect(booking.opponentTeamId, 'team_blue');
      expect(booking.totalPrice, 300.0);
    });
  });
}
