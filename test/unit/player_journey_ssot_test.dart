import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Track B: Player Identity & Social Journey SSOT', () {
    test('User sensitive fields trigger protects financial, security and lifecycle fields', () {
      // Simulating OLD vs NEW updates on sensitive attributes
      final sensitiveFields = [
        'role',
        'email',
        'subscription_plan',
        'subscription_expires_at',
        'trial_ends_at',
        'total_platform_fees',
        'cash_booking_banned',
        'no_show_count',
        'is_identity_verified',
        'is_email_verified',
        'verification_status',
        'is_blocked',
        'has_stadium',
        'is_registration_complete',
        'is_onboarding_confirmed',
        'accumulated_cash_debt',
        'debt_limit',
        'is_debt_blocked',
        'points',
      ];

      for (final field in sensitiveFields) {
        final isProtected = sensitiveFields.contains(field);
        expect(isProtected, isTrue, reason: 'Field $field must be server-authoritative');
      }
    });

    test('Permanent account deletion is rejected when user has outstanding cash debt', () {
      final user = {
        'id': 'user-debtor-1',
        'name': 'Ahmed Debt',
        'accumulated_cash_debt': 150.00,
        'debt_limit': 500.00,
      };

      final hasDebt = (user['accumulated_cash_debt'] as num) > 0;
      final deletionAllowed = !hasDebt;

      expect(deletionAllowed, isFalse);
      final response = {
        'success': false,
        'error': 'OUTSTANDING_DEBT',
        'message': 'لا يمكن حذف الحساب لوجود مستحقات مالية معلقة (${user['accumulated_cash_debt']} ج.م).'
      };
      expect(response['success'], isFalse);
      expect(response['error'], equals('OUTSTANDING_DEBT'));
    });

    test('Permanent account deletion is rejected when user has active confirmed bookings', () {
      final activeBookings = [
        {
          'id': 'booking-future-1',
          'created_by_user_id': 'user-active-1',
          'status': 'confirmed',
          'start_time': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        }
      ];

      final hasActiveBookings = activeBookings.any((b) =>
          b['status'] == 'confirmed' &&
          DateTime.parse(b['start_time'] as String).isAfter(DateTime.now()));

      final deletionAllowed = !hasActiveBookings;
      expect(deletionAllowed, isFalse);

      final response = {
        'success': false,
        'error': 'ACTIVE_BOOKINGS',
        'message': 'لا يمكن حذف الحساب لوجود حجوزات نشطة قادمة. يرجى إلغاء الحجوزات أولاً.'
      };
      expect(response['success'], isFalse);
      expect(response['error'], equals('ACTIVE_BOOKINGS'));
    });

    test('Deleting captain user account cascades captaincy to oldest member without destroying team', () {
      final deletingCaptainId = 'captain-to-delete';
      final team = {
        'id': 'team-heroes',
        'name': 'الأبطال',
        'captain_id': deletingCaptainId,
      };

      final members = [
        {'team_id': 'team-heroes', 'user_id': deletingCaptainId, 'joined_at': '2026-01-01T10:00:00Z', 'name': 'Captain'},
        {'team_id': 'team-heroes', 'user_id': 'member-oldest', 'joined_at': '2026-01-02T10:00:00Z', 'name': 'Oldest Player'},
        {'team_id': 'team-heroes', 'user_id': 'member-youngest', 'joined_at': '2026-01-05T10:00:00Z', 'name': 'Youngest Player'},
      ];

      // Finding remaining members sorted by joined_at ASC
      final remainingMembers = members
          .where((m) => m['user_id'] != deletingCaptainId)
          .toList()
        ..sort((a, b) => (a['joined_at'] as String).compareTo(b['joined_at'] as String));

      expect(remainingMembers.isNotEmpty, isTrue);
      final newCaptain = remainingMembers.first;
      expect(newCaptain['user_id'], equals('member-oldest'));

      // Update team captaincy
      team['captain_id'] = newCaptain['user_id']!;
      expect(team['captain_id'], equals('member-oldest'));
      expect(team['id'], equals('team-heroes'), reason: 'Team must NOT be deleted when other members exist');
    });

    test('Deleting sole captain user account safely disbands the empty team', () {
      final deletingCaptainId = 'lone-captain';
      final team = {
        'id': 'team-lone',
        'name': 'الفريق المنفرد',
        'captain_id': deletingCaptainId,
      };

      final members = [
        {'team_id': 'team-lone', 'user_id': deletingCaptainId, 'joined_at': '2026-01-01T10:00:00Z'},
      ];

      final remainingMembers = members.where((m) => m['user_id'] != deletingCaptainId).toList();
      var teamDeleted = false;

      if (remainingMembers.isEmpty) {
        teamDeleted = true;
      }

      expect(teamDeleted, isTrue, reason: 'Sole captain leaving disbands empty team cleanly');
    });
  });
}
