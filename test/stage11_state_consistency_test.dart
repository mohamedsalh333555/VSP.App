import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/core/providers/booking/booking_categorization_service.dart';

void main() {
  group('Stage 11: BookingMapper Numeric & Null Safety', () {
    test('Correctly parses String, num, and null numeric values without runtime cast exceptions', () {
      final dataWithStringNumbers = {
        'stadium_id': 'stad_1',
        'stadium_name': 'Test Stadium',
        'total_price': '250.75',
        'deposit_paid': '50.25',
        'home_score': '4',
        'away_score': '2',
        'current_players': '8',
        'players_per_team': '6',
        'emergency_downtime_hours': '3',
        'refund_amount': '100.50',
        'status': 'confirmed',
        'start_time': '2026-09-14T20:00:00.000Z',
        'end_time': '2026-09-14T21:00:00.000Z',
      };

      final booking = BookingMapper.fromFirestore(dataWithStringNumbers, 'test_bk_1');

      expect(booking.totalPrice, 250.75);
      expect(booking.depositPaid, 50.25);
      expect(booking.homeScore, 4);
      expect(booking.awayScore, 2);
      expect(booking.currentPlayers, 8);
      expect(booking.playersPerTeam, 6);
      expect(booking.emergencyDowntimeHours, 3);
      expect(booking.refundAmount, 100.50);
    });

    test('Correctly falls back on null numeric values without throwing null errors', () {
      final dataWithNulls = {
        'stadium_id': 'stad_2',
        'stadium_name': 'Null Stadium',
        'total_price': null,
        'deposit_paid': null,
        'home_score': null,
        'away_score': null,
        'current_players': null,
        'players_per_team': null,
        'emergency_downtime_hours': null,
        'refund_amount': null,
        'status': 'pending',
        'start_time': '2026-09-14T20:00:00.000Z',
        'end_time': '2026-09-14T21:00:00.000Z',
      };

      final booking = BookingMapper.fromFirestore(dataWithNulls, 'test_bk_2');

      expect(booking.totalPrice, 0.0);
      expect(booking.depositPaid, 0.0);
      expect(booking.homeScore, isNull);
      expect(booking.awayScore, isNull);
      expect(booking.currentPlayers, 1);
      expect(booking.playersPerTeam, 5);
      expect(booking.emergencyDowntimeHours, isNull);
      expect(booking.refundAmount, isNull);
    });
  });

  group('Stage 11: BookingMapper Status Mapping', () {
    test('Maps legacy "upcoming" status to BookingStatus.confirmed', () {
      final data = {
        'status': 'upcoming',
        'start_time': '2026-09-14T20:00:00.000Z',
        'end_time': '2026-09-14T21:00:00.000Z',
      };
      final booking = BookingMapper.fromFirestore(data, 'bk_up');
      expect(booking.status, BookingStatus.confirmed);
    });

    test('Maps standard status strings to their respective enums', () {
      for (final status in BookingStatus.values) {
        if (status == BookingStatus.upcoming) continue;
        final data = {
          'status': status.name,
          'start_time': '2026-09-14T20:00:00.000Z',
          'end_time': '2026-09-14T21:00:00.000Z',
        };
        final booking = BookingMapper.fromFirestore(data, 'bk_${status.name}');
        expect(booking.status, status);
      }
    });

    test('Safely handles unknown status by falling back to BookingStatus.pending', () {
      final data = {
        'status': 'corrupted_state_xyz',
        'start_time': '2026-09-14T20:00:00.000Z',
        'end_time': '2026-09-14T21:00:00.000Z',
      };
      final booking = BookingMapper.fromFirestore(data, 'bk_unknown');
      expect(booking.status, BookingStatus.pending);
    });
  });

  group('Stage 11: BookingCategorizationService Invariants', () {
    final now = DateTime(2026, 9, 14, 20, 0);

    test('Pending booking is strictly placed in pending, NEVER in upcoming', () {
      final pendingBooking = Booking(
        id: 'bk_pending_1',
        stadiumId: 'stad_1',
        stadiumName: 'Stadium 1',
        stadiumImageUrl: '',
        ownerId: 'owner_1',
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 3)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 200,
        currency: 'EGP',
        paymentMethod: 'cash',
        status: BookingStatus.pending,
        isPaid: false,
        createdByUserId: 'user_1',
        createdAt: now.subtract(const Duration(minutes: 5)),
        matchResultStatus: MatchResultStatus.noResult,
        requiresAdminIntervention: false,
        currentPlayers: 1,
        playersPerTeam: 5,
        totalFieldCapacity: 10,
        pendingUserIds: [],
        joinedUserIds: [],
        paymentStatus: 'pending',
        depositPaid: 0,
        isDepositPaid: false,
        rescheduleStatus: 'none',
        emergencyCancelStatus: 'none',
      );

      final categorized = BookingCategorizationService.categorizeUserBookings(
        bookings: [pendingBooking],
        now: now,
      );

      // CRITICAL Stage 11 invariant:
      expect(categorized.pending.length, 1);
      expect(categorized.pending.first.id, 'bk_pending_1');
      expect(categorized.upcoming, isEmpty);
      expect(categorized.history, isEmpty);
    });

    test('Confirmed future booking is placed in upcoming, NOT in pending or history', () {
      final confirmedBooking = Booking(
        id: 'bk_confirmed_1',
        stadiumId: 'stad_1',
        stadiumName: 'Stadium 1',
        stadiumImageUrl: '',
        ownerId: 'owner_1',
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 3)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 200,
        currency: 'EGP',
        paymentMethod: 'cash',
        status: BookingStatus.confirmed,
        isPaid: false,
        createdByUserId: 'user_1',
        createdAt: now.subtract(const Duration(hours: 1)),
        matchResultStatus: MatchResultStatus.noResult,
        requiresAdminIntervention: false,
        currentPlayers: 1,
        playersPerTeam: 5,
        totalFieldCapacity: 10,
        pendingUserIds: [],
        joinedUserIds: [],
        paymentStatus: 'pending',
        depositPaid: 0,
        isDepositPaid: false,
        rescheduleStatus: 'none',
        emergencyCancelStatus: 'none',
      );

      final categorized = BookingCategorizationService.categorizeUserBookings(
        bookings: [confirmedBooking],
        now: now,
      );

      expect(categorized.upcoming.length, 1);
      expect(categorized.upcoming.first.id, 'bk_confirmed_1');
      expect(categorized.pending, isEmpty);
      expect(categorized.history, isEmpty);
    });

    test('Completed, cancelled, and expired confirmed bookings belong strictly to history', () {
      final completedBooking = Booking(
        id: 'bk_comp',
        stadiumId: 'stad_1',
        stadiumName: 'Stadium 1',
        stadiumImageUrl: '',
        ownerId: 'owner_1',
        startTime: now.subtract(const Duration(hours: 3)),
        endTime: now.subtract(const Duration(hours: 2)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 200,
        currency: 'EGP',
        paymentMethod: 'cash',
        status: BookingStatus.completed,
        isPaid: true,
        createdByUserId: 'user_1',
        createdAt: now.subtract(const Duration(hours: 5)),
        matchResultStatus: MatchResultStatus.noResult,
        requiresAdminIntervention: false,
        currentPlayers: 1,
        playersPerTeam: 5,
        totalFieldCapacity: 10,
        pendingUserIds: [],
        joinedUserIds: [],
        paymentStatus: 'paid',
        depositPaid: 0,
        isDepositPaid: false,
        rescheduleStatus: 'none',
        emergencyCancelStatus: 'none',
      );

      final cancelledBooking = Booking(
        id: 'bk_canc',
        stadiumId: 'stad_1',
        stadiumName: 'Stadium 1',
        stadiumImageUrl: '',
        ownerId: 'owner_1',
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 200,
        currency: 'EGP',
        paymentMethod: 'cash',
        status: BookingStatus.cancelled,
        isPaid: false,
        createdByUserId: 'user_1',
        createdAt: now.subtract(const Duration(hours: 1)),
        matchResultStatus: MatchResultStatus.noResult,
        requiresAdminIntervention: false,
        currentPlayers: 1,
        playersPerTeam: 5,
        totalFieldCapacity: 10,
        pendingUserIds: [],
        joinedUserIds: [],
        paymentStatus: 'pending',
        depositPaid: 0,
        isDepositPaid: false,
        rescheduleStatus: 'none',
        emergencyCancelStatus: 'none',
      );

      final pastConfirmedBooking = Booking(
        id: 'bk_past_conf',
        stadiumId: 'stad_1',
        stadiumName: 'Stadium 1',
        stadiumImageUrl: '',
        ownerId: 'owner_1',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.subtract(const Duration(hours: 1)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 200,
        currency: 'EGP',
        paymentMethod: 'cash',
        status: BookingStatus.confirmed,
        isPaid: true,
        createdByUserId: 'user_1',
        createdAt: now.subtract(const Duration(hours: 4)),
        matchResultStatus: MatchResultStatus.noResult,
        requiresAdminIntervention: false,
        currentPlayers: 1,
        playersPerTeam: 5,
        totalFieldCapacity: 10,
        pendingUserIds: [],
        joinedUserIds: [],
        paymentStatus: 'paid',
        depositPaid: 0,
        isDepositPaid: false,
        rescheduleStatus: 'none',
        emergencyCancelStatus: 'none',
      );

      final categorized = BookingCategorizationService.categorizeUserBookings(
        bookings: [completedBooking, cancelledBooking, pastConfirmedBooking],
        now: now,
      );

      expect(categorized.history.length, 3);
      expect(categorized.upcoming, isEmpty);
      expect(categorized.pending, isEmpty);
    });
  });
}
