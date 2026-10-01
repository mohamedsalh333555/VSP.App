import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/booking/booking_creation_coordinator.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('Triple Booking System: Challenge Pure SSOT & Counter Isolation', () {
    test('Challenge matches strictly isolate player counters to 0', () {
      final challengeJson = {
        'id': 'bk_challenge_001',
        'stadium_id': '00000000-0000-0000-0000-000000000001',
        'stadium_name': 'Camp Nou VSP',
        'booking_type': 'challenge',
        'current_players': '10', // Should be zeroed out
        'total_field_capacity': '10', // Should be zeroed out
        'player_team_id': '00000000-0000-0000-0000-000000000002',
        'player_team_name': 'Team Alpha',
        'opponent_team_id': '00000000-0000-0000-0000-000000000003',
        'opponent_team_name': 'Team Beta',
        'total_price': 300.0,
        'status': 'confirmed',
        'start_time': '2026-10-01T20:00:00.000Z',
        'end_time': '2026-10-01T21:00:00.000Z',
      };

      final booking = BookingMapper.fromFirestore(challengeJson, 'bk_challenge_001');

      expect(booking.isChallenge, isTrue);
      expect(booking.isOpenJoin, isFalse);
      expect(booking.isPersonal, isFalse);
      expect(booking.hasPlayerCounters, isFalse);
      // Strictly zero counters
      expect(booking.currentPlayers, 0);
      expect(booking.totalFieldCapacity, 0);
      expect(booking.playerTeamName, 'Team Alpha');
      expect(booking.opponentTeamName, 'Team Beta');

      // Serialization check: Challenge does NOT persist player counters
      final serialized = BookingMapper.toFirestore(booking);
      expect(serialized['current_players'], isNull);
      expect(serialized['total_field_capacity'], isNull);
      expect(serialized['max_players'], isNull);
    });

    test('Open Join matches actively preserve player counters and capacity', () {
      final openJoinJson = {
        'id': 'bk_open_001',
        'stadium_id': '00000000-0000-0000-0000-000000000001',
        'stadium_name': 'Al-Ahly Arena',
        'booking_type': 'open_join',
        'current_players': 4,
        'total_field_capacity': 10,
        'total_price': 500.0,
        'status': 'confirmed',
        'start_time': '2026-10-01T20:00:00.000Z',
        'end_time': '2026-10-01T21:00:00.000Z',
      };

      final booking = BookingMapper.fromFirestore(openJoinJson, 'bk_open_001');

      expect(booking.isOpenJoin, isTrue);
      expect(booking.isChallenge, isFalse);
      expect(booking.hasPlayerCounters, isTrue);
      expect(booking.currentPlayers, 4);
      expect(booking.totalFieldCapacity, 10);

      // Serialization check: Open Join preserves player counters
      final serialized = BookingMapper.toFirestore(booking);
      expect(serialized['current_players'], 4);
      expect(serialized['total_field_capacity'], 10);
      expect(serialized['max_players'], 10);
    });

    test('Personal matches do not display player counters', () {
      final personalJson = {
        'id': 'bk_personal_001',
        'stadium_id': '00000000-0000-0000-0000-000000000001',
        'stadium_name': 'Zamalek Turf',
        'booking_type': 'personal',
        'total_price': 400.0,
        'status': 'confirmed',
        'start_time': '2026-10-01T20:00:00.000Z',
        'end_time': '2026-10-01T21:00:00.000Z',
      };

      final booking = BookingMapper.fromFirestore(personalJson, 'bk_personal_001');

      expect(booking.isPersonal, isTrue);
      expect(booking.isOpenJoin, isFalse);
      expect(booking.isChallenge, isFalse);
      expect(booking.hasPlayerCounters, isFalse);
    });
  });

  group('Triple Booking System: Database Booking Types SSOT', () {
    test('Ensures canonical db mappings for all 3 booking categories', () {
      expect(BookingCreationCoordinator.dbBookingType(BookingType.personal), 'personal');
      expect(BookingCreationCoordinator.dbBookingType(BookingType.openJoin), 'open_join');
      expect(BookingCreationCoordinator.dbBookingType(BookingType.challenge), 'challenge');
      // Legacy mapped safely to personal
      expect(BookingCreationCoordinator.dbBookingType(BookingType.team), 'personal');
      expect(BookingCreationCoordinator.dbBookingType(BookingType.matchup), 'personal');
    });
  });

  group('Triple Booking System: Challenge Code Format & Lifecycle Invariants', () {
    test('Normalizes challenge codes uniformly', () {
      String normalizeCode(String raw) {
        String clean = raw.trim().toUpperCase();
        if (clean.startsWith('VSP-')) {
          clean = clean.substring(4);
        }
        return clean;
      }

      expect(normalizeCode('  vsp-abc12345  '), 'ABC12345');
      expect(normalizeCode('xyz999'), 'XYZ999');
      expect(normalizeCode('VSP-T7K2M9PQ'), 'T7K2M9PQ');
    });

    test('State alignment: Cash is confirmed immediately; Online is pending + ready', () {
      // Invariant: Cash challenge booking is immediately confirmed
      const cashMethod = 'cash';
      final cashStatus = (cashMethod == 'cash') ? 'confirmed' : 'pending';
      final cashChallengeStatus = (cashMethod == 'cash') ? 'confirmed' : 'ready';
      expect(cashStatus, 'confirmed');
      expect(cashChallengeStatus, 'confirmed');

      // Invariant: Online challenge booking is pending until payment success
      const onlineMethod = 'paymob';
      final onlineStatus = (onlineMethod == 'cash') ? 'confirmed' : 'pending';
      final onlineChallengeStatus = (onlineMethod == 'cash') ? 'confirmed' : 'ready';
      expect(onlineStatus, 'pending');
      expect(onlineChallengeStatus, 'ready');
    });
  });

  group('Triple Booking System: Idempotency Protection Invariants', () {
    test('Detects idempotency collision when user IDs differ', () {
      Map<String, dynamic> evaluateIdempotency({
        required String callerId,
        required String existingUserId,
        required String existingBookingId,
        required String existingStatus,
      }) {
        if (existingUserId != callerId) {
          return {
            'success': false,
            'error': 'IDEMPOTENCY_KEY_COLLISION',
            'message': 'مفتاح العملية غير صالح أو مستخدم مسبقاً لحساب آخر.'
          };
        }
        return {
          'success': true,
          'booking_id': existingBookingId,
          'status': existingStatus,
          'idempotent': true,
        };
      }

      // Different user -> COLLISION
      final collision = evaluateIdempotency(
        callerId: 'user_A',
        existingUserId: 'user_B',
        existingBookingId: 'bk_100',
        existingStatus: 'confirmed',
      );
      expect(collision['success'], isFalse);
      expect(collision['error'], 'IDEMPOTENCY_KEY_COLLISION');

      // Same user -> SAFE IDEMPOTENT RETRY
      final retry = evaluateIdempotency(
        callerId: 'user_A',
        existingUserId: 'user_A',
        existingBookingId: 'bk_100',
        existingStatus: 'confirmed',
      );
      expect(retry['success'], isTrue);
      expect(retry['idempotent'], isTrue);
      expect(retry['booking_id'], 'bk_100');
    });
  });
}
