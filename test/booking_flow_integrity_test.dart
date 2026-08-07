import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('A. Booking Flow & 0% SaaS Model Integrity Tests', () {
    test('1. Personal Booking preserves 0% Platform Fee & exact stadium price', () {
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
        totalPrice: 200.0, // Exact stadium price set by owner
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

      // 🛡️ Verification of 0% Commission & Model Precision
      expect(booking.totalPrice, 200.0, reason: 'Player pays strictly 200 EGP without added commission');
      expect(booking.stadiumId, 'stad_cairo_1');
      expect(booking.paymentMethod, 'cash');
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.createdByUserId, 'user_123');
    });

    test('2. Cash-only MVP: Default paymentMethod is cash when omitted', () {
      final draft = BookingDraft(
        stadiumId: 's1',
        stadiumName: 'Test Pitch',
        ownerId: 'o1',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 150,
      );

      final booking = Booking.fromDraft(
        id: 'bk_002',
        draft: draft,
        userId: 'u1',
        status: BookingStatus.confirmed,
      );

      expect(booking.paymentMethod, 'cash', reason: 'Default payment method must be cash');
    });
  });

  group('B. Challenge Booking & Opponent Isolation', () {
    test('Challenge booking preserves opponent details without extra fees', () {
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
        id: 'bk_003',
        draft: draft,
        userId: 'u1',
        status: BookingStatus.confirmed,
      );

      expect(booking.bookingType, BookingType.challenge);
      expect(booking.playerTeamId, 'team_red');
      expect(booking.opponentTeamId, 'team_blue');
      expect(booking.totalPrice, 300.0);
    });
  });
}
