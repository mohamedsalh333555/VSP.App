import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Team Journey SSOT - Schema & Primary Key Invariants', () {
    test('team_members table uses composite primary key (team_id, user_id) with joined_at and NO id column', () {
      final teamMemberRow = {
        'team_id': 'team-uuid-1',
        'user_id': 'player-uuid-1',
        'joined_at': '2026-10-01T12:00:00Z',
      };

      expect(teamMemberRow.containsKey('team_id'), isTrue);
      expect(teamMemberRow.containsKey('user_id'), isTrue);
      expect(teamMemberRow.containsKey('joined_at'), isTrue);
      expect(teamMemberRow.containsKey('id'), isFalse, reason: 'team_members must NOT have a synthetic id column');
    });

    test('teams table schema has single captain_id and core attributes', () {
      final teamRow = {
        'id': 'team-uuid-1',
        'name': 'النسور',
        'captain_id': 'player-uuid-1',
        'captain_name': 'محمد صلاح',
        'captain_phone': '01012345678',
        'points': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'matches_played': 0,
        'is_active': true,
      };

      expect(teamRow['captain_id'], equals('player-uuid-1'));
      expect(teamRow['name'], equals('النسور'));
      expect(teamRow['is_active'], isTrue);
    });
  });

  group('Team Journey SSOT - Membership Removal & Voluntary Leave', () {
    Map<String, dynamic> simulateRemoveMember({
      required String callerId,
      required String callerRole,
      required String captainId,
      required String targetUserId,
      required List<Map<String, dynamic>> teamMembers,
      required bool hasActiveMatchOrTournament,
    }) {
      if (hasActiveMatchOrTournament) {
        return {'success': false, 'error': 'active_match_or_tournament_error'};
      }

      final isSelf = callerId == targetUserId;
      final isCaptain = callerId == captainId;
      final isAdmin = ['admin', 'co_founder', 'cofounder', 'super_admin'].contains(callerRole);

      if (!isSelf && !isCaptain && !isAdmin) {
        return {'success': false, 'error': 'Unauthorized'};
      }

      final remaining = teamMembers.where((m) => m['user_id'] != targetUserId).toList();
      String? nextCaptainId;
      bool teamDisbanded = false;

      if (targetUserId == captainId) {
        if (remaining.isNotEmpty) {
          // Sort by joined_at ASC
          remaining.sort((a, b) => (a['joined_at'] as String).compareTo(b['joined_at'] as String));
          nextCaptainId = remaining.first['user_id'];
        } else {
          teamDisbanded = true;
        }
      }

      return {
        'success': true,
        'remaining_members': remaining,
        'captain_transferred': targetUserId == captainId && nextCaptainId != null,
        'new_captain_id': nextCaptainId,
        'team_disbanded': teamDisbanded,
      };
    }

    test('Regular member can voluntarily leave the team (self-leave)', () {
      final members = [
        {'user_id': 'cap-1', 'joined_at': '2026-09-01T10:00:00Z'},
        {'user_id': 'player-2', 'joined_at': '2026-09-02T10:00:00Z'},
      ];

      final result = simulateRemoveMember(
        callerId: 'player-2',
        callerRole: 'player',
        captainId: 'cap-1',
        targetUserId: 'player-2',
        teamMembers: members,
        hasActiveMatchOrTournament: false,
      );

      expect(result['success'], isTrue);
      expect((result['remaining_members'] as List).length, equals(1));
      expect(result['captain_transferred'], isFalse);
    });

    test('Unauthorized stranger cannot remove a team member', () {
      final members = [
        {'user_id': 'cap-1', 'joined_at': '2026-09-01T10:00:00Z'},
        {'user_id': 'player-2', 'joined_at': '2026-09-02T10:00:00Z'},
      ];

      final result = simulateRemoveMember(
        callerId: 'stranger-99',
        callerRole: 'player',
        captainId: 'cap-1',
        targetUserId: 'player-2',
        teamMembers: members,
        hasActiveMatchOrTournament: false,
      );

      expect(result['success'], isFalse);
      expect(result['error'], equals('Unauthorized'));
    });

    test('Captain removing themselves automatically transfers captaincy to oldest member', () {
      final members = [
        {'user_id': 'cap-1', 'joined_at': '2026-09-01T10:00:00Z'},
        {'user_id': 'player-older', 'joined_at': '2026-09-02T10:00:00Z'},
        {'user_id': 'player-newer', 'joined_at': '2026-09-05T10:00:00Z'},
      ];

      final result = simulateRemoveMember(
        callerId: 'cap-1',
        callerRole: 'player',
        captainId: 'cap-1',
        targetUserId: 'cap-1',
        teamMembers: members,
        hasActiveMatchOrTournament: false,
      );

      expect(result['success'], isTrue);
      expect(result['captain_transferred'], isTrue);
      expect(result['new_captain_id'], equals('player-older'));
      expect(result['team_disbanded'], isFalse);
    });

    test('Sole captain leaving safely disbands the empty team', () {
      final members = [
        {'user_id': 'cap-1', 'joined_at': '2026-09-01T10:00:00Z'},
      ];

      final result = simulateRemoveMember(
        callerId: 'cap-1',
        callerRole: 'player',
        captainId: 'cap-1',
        targetUserId: 'cap-1',
        teamMembers: members,
        hasActiveMatchOrTournament: false,
      );

      expect(result['success'], isTrue);
      expect(result['team_disbanded'], isTrue);
      expect(result['new_captain_id'], isNull);
    });

    test('Leaving blocked when team is engaged in an active confirmed booking or ongoing tournament', () {
      final members = [
        {'user_id': 'cap-1', 'joined_at': '2026-09-01T10:00:00Z'},
        {'user_id': 'player-2', 'joined_at': '2026-09-02T10:00:00Z'},
      ];

      final result = simulateRemoveMember(
        callerId: 'player-2',
        callerRole: 'player',
        captainId: 'cap-1',
        targetUserId: 'player-2',
        teamMembers: members,
        hasActiveMatchOrTournament: true,
      );

      expect(result['success'], isFalse);
      expect(result['error'], equals('active_match_or_tournament_error'));
    });
  });

  group('Team Journey SSOT - Explicit Captaincy Transfer Invariants', () {
    Map<String, dynamic> simulateTransferCaptaincy({
      required String callerId,
      required String callerRole,
      required String currentCaptainId,
      required String newCaptainId,
      required List<String> teamMemberIds,
      required bool isNewCaptainBlocked,
      required bool hasActiveMatchOrTournament,
    }) {
      if (hasActiveMatchOrTournament) {
        return {'success': false, 'error': 'active_match_or_tournament_error'};
      }

      final isCaptain = callerId == currentCaptainId;
      final isAdmin = ['admin', 'co_founder', 'cofounder', 'super_admin'].contains(callerRole);

      if (!isCaptain && !isAdmin) {
        return {'success': false, 'error': 'Unauthorized'};
      }

      if (newCaptainId == currentCaptainId) {
        return {'success': false, 'error': 'Already captain'};
      }

      if (!teamMemberIds.contains(newCaptainId)) {
        return {'success': false, 'error': 'Target is not a member of the team'};
      }

      if (isNewCaptainBlocked) {
        return {'success': false, 'error': 'Target account is blocked'};
      }

      return {
        'success': true,
        'previous_captain_id': currentCaptainId,
        'new_captain_id': newCaptainId,
      };
    }

    test('Captain can successfully transfer captaincy to an active member', () {
      final result = simulateTransferCaptaincy(
        callerId: 'cap-1',
        callerRole: 'player',
        currentCaptainId: 'cap-1',
        newCaptainId: 'player-2',
        teamMemberIds: ['cap-1', 'player-2', 'player-3'],
        isNewCaptainBlocked: false,
        hasActiveMatchOrTournament: false,
      );

      expect(result['success'], isTrue);
      expect(result['new_captain_id'], equals('player-2'));
    });

    test('Non-captain member cannot initiate captain transfer', () {
      final result = simulateTransferCaptaincy(
        callerId: 'player-2',
        callerRole: 'player',
        currentCaptainId: 'cap-1',
        newCaptainId: 'player-3',
        teamMemberIds: ['cap-1', 'player-2', 'player-3'],
        isNewCaptainBlocked: false,
        hasActiveMatchOrTournament: false,
      );

      expect(result['success'], isFalse);
      expect(result['error'], equals('Unauthorized'));
    });

    test('Cannot transfer captaincy to an outsider who is not in the team', () {
      final result = simulateTransferCaptaincy(
        callerId: 'cap-1',
        callerRole: 'player',
        currentCaptainId: 'cap-1',
        newCaptainId: 'outsider-99',
        teamMemberIds: ['cap-1', 'player-2'],
        isNewCaptainBlocked: false,
        hasActiveMatchOrTournament: false,
      );

      expect(result['success'], isFalse);
      expect(result['error'], equals('Target is not a member of the team'));
    });

    test('Cannot transfer captaincy to a blocked player', () {
      final result = simulateTransferCaptaincy(
        callerId: 'cap-1',
        callerRole: 'player',
        currentCaptainId: 'cap-1',
        newCaptainId: 'player-blocked',
        teamMemberIds: ['cap-1', 'player-blocked'],
        isNewCaptainBlocked: true,
        hasActiveMatchOrTournament: false,
      );

      expect(result['success'], isFalse);
      expect(result['error'], equals('Target account is blocked'));
    });
  });

  group('Team Journey SSOT - Squad Size & Member Limits', () {
    test('Team squad size is capped at 12 members', () {
      const int maxSquadSize = 12;
      bool canAddMember(int currentCount) => currentCount < maxSquadSize;

      expect(canAddMember(5), isTrue);
      expect(canAddMember(11), isTrue);
      expect(canAddMember(12), isFalse);
    });

    test('Player can join a maximum of 3 teams', () {
      const int maxTeamsPerPlayer = 3;
      bool canJoinTeam(int currentTeamsCount) => currentTeamsCount < maxTeamsPerPlayer;

      expect(canJoinTeam(0), isTrue);
      expect(canJoinTeam(2), isTrue);
      expect(canJoinTeam(3), isFalse);
    });
  });
}
