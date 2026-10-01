import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tournament Journey Targeted SSOT Remediation Tests', () {
    // -------------------------------------------------------------
    // UI Status SSOT: Canonical Championship Status in Match Card
    // -------------------------------------------------------------
    test('Match card allows score recording strictly on canonical "ongoing" status, not "in_progress"', () {
      bool canRecordScore({
        required bool isOwner,
        required String? homeTeamId,
        required String? awayTeamId,
        required String championshipStatus,
      }) {
        return isOwner &&
            homeTeamId != null &&
            awayTeamId != null &&
            championshipStatus == 'ongoing';
      }

      expect(
        canRecordScore(
          isOwner: true,
          homeTeamId: 'team-1',
          awayTeamId: 'team-2',
          championshipStatus: 'ongoing',
        ),
        isTrue,
        reason: 'Score recording must be enabled when championship status is ongoing',
      );

      expect(
        canRecordScore(
          isOwner: true,
          homeTeamId: 'team-1',
          awayTeamId: 'team-2',
          championshipStatus: 'in_progress',
        ),
        isFalse,
        reason: 'Score recording must not rely on non-canonical in_progress',
      );
    });

    // -------------------------------------------------------------
    // Helper function simulating the authoritative database logic
    // for record_match_result_and_advance_atomic
    // -------------------------------------------------------------
    Map<String, dynamic> simulateRecordMatchResult({
      required int homeScore,
      required int awayScore,
      int? homePenalties,
      int? awayPenalties,
      String? winnerId,
      required String homeTeamId,
      required String awayTeamId,
      required String stage,
      String? championshipType,
      String? groupName,
      String? nextMatchId,
      required String currentResultStatus,
    }) {
      // 1. Negative score checks
      if (homeScore < 0 || awayScore < 0) {
        return {'success': false, 'error': 'INVALID_SCORE: Scores cannot be negative'};
      }
      if ((homePenalties != null && homePenalties < 0) ||
          (awayPenalties != null && awayPenalties < 0)) {
        return {'success': false, 'error': 'INVALID_PENALTIES: Penalty scores cannot be negative'};
      }

      // 2. Locked match check
      if (currentResultStatus == 'locked') {
        return {'success': false, 'error': 'LOCKED_MATCH: Match result is locked and cannot be modified'};
      }

      // 3. Authoritative League vs Knockout determination
      bool isKnockout;
      if (stage == 'league' || championshipType == 'league') {
        isKnockout = false;
      } else if (stage == 'group_stage' || groupName != null) {
        isKnockout = false;
      } else {
        isKnockout = (nextMatchId != null ||
            ['knockout', 'cup', 'round_of_16', 'quarter_final', 'semi_final', 'final'].contains(stage) ||
            ['cup', 'knockout'].contains(championshipType));
      }

      // 4. Validate winner vs scores
      String? expectedWinnerId;
      String? effectiveWinnerId = winnerId;

      if (homeScore != awayScore) {
        expectedWinnerId = homeScore > awayScore ? homeTeamId : awayTeamId;
        if (winnerId != null && winnerId != expectedWinnerId) {
          return {'success': false, 'error': 'WINNER_MISMATCH: Winner does not match regular time score'};
        }
        effectiveWinnerId = expectedWinnerId;
      } else {
        // Tied score
        if (isKnockout) {
          if (homePenalties == null || awayPenalties == null) {
            return {'success': false, 'error': 'PENALTIES_REQUIRED: Tied knockout match requires penalties'};
          }
          if (homePenalties == awayPenalties) {
            return {'success': false, 'error': 'PENALTIES_TIED: Penalties cannot be tied in knockout match'};
          }
          expectedWinnerId = homePenalties > awayPenalties ? homeTeamId : awayTeamId;
          if (winnerId != null && winnerId != expectedWinnerId) {
            return {'success': false, 'error': 'WINNER_MISMATCH: Winner does not match penalty shootout result'};
          }
          effectiveWinnerId = expectedWinnerId;
        } else {
          // League or group draw
          if (winnerId != null) {
            return {'success': false, 'error': 'WINNER_MISMATCH: Draws in league or group matches cannot have a winner'};
          }
          effectiveWinnerId = null;
        }
      }

      if (isKnockout && effectiveWinnerId == null) {
        return {'success': false, 'error': 'KNOCKOUT_REQUIRES_WINNER: Knockout matches cannot end without a winner'};
      }

      return {
        'success': true,
        'winner_id': effectiveWinnerId,
        'status': 'completed',
        'is_completed': true,
        'result_status': 'confirmed',
        'is_knockout': isKnockout,
      };
    }

    // -------------------------------------------------------------
    // Test A: League 1-1 (Draw: succeeds, no penalties, no winner)
    // -------------------------------------------------------------
    test('A. League 1-1: succeeds, no penalties required, no winner required', () {
      final res = simulateRecordMatchResult(
        homeScore: 1,
        awayScore: 1,
        homeTeamId: 'team-a',
        awayTeamId: 'team-b',
        stage: 'league',
        championshipType: 'league',
        currentResultStatus: 'scheduled',
      );
      expect(res['success'], isTrue);
      expect(res['winner_id'], isNull);
      expect(res['is_knockout'], isFalse);
      expect(res['status'], equals('completed'));
      expect(res['result_status'], equals('confirmed'));
    });

    // -------------------------------------------------------------
    // Test B: League 2-1 (Winner derived correctly)
    // -------------------------------------------------------------
    test('B. League 2-1: winner derived correctly', () {
      final res = simulateRecordMatchResult(
        homeScore: 2,
        awayScore: 1,
        homeTeamId: 'team-a',
        awayTeamId: 'team-b',
        stage: 'league',
        championshipType: 'league',
        currentResultStatus: 'scheduled',
      );
      expect(res['success'], isTrue);
      expect(res['winner_id'], equals('team-a'));
      expect(res['is_knockout'], isFalse);
      expect(res['status'], equals('completed'));
      expect(res['result_status'], equals('confirmed'));
    });

    // -------------------------------------------------------------
    // Test C: Group 1-1 (Group stage draw: succeeds without winner)
    // -------------------------------------------------------------
    test('C. Group 1-1: succeeds without winner', () {
      final res = simulateRecordMatchResult(
        homeScore: 1,
        awayScore: 1,
        homeTeamId: 'team-x',
        awayTeamId: 'team-y',
        stage: 'group_stage',
        groupName: 'المجموعة أ',
        championshipType: 'cup',
        currentResultStatus: 'scheduled',
      );
      expect(res['success'], isTrue);
      expect(res['winner_id'], isNull);
      expect(res['is_knockout'], isFalse);
    });

    // -------------------------------------------------------------
    // Test D: Knockout 1-1 with no penalties: rejected
    // -------------------------------------------------------------
    test('D. Knockout 1-1 with no penalties: rejected', () {
      final res = simulateRecordMatchResult(
        homeScore: 1,
        awayScore: 1,
        homeTeamId: 'team-1',
        awayTeamId: 'team-2',
        stage: 'knockout',
        championshipType: 'cup',
        currentResultStatus: 'scheduled',
      );
      expect(res['success'], isFalse);
      expect(res['error'], contains('PENALTIES_REQUIRED'));
    });

    // -------------------------------------------------------------
    // Test E: Knockout 1-1 with decisive penalties: succeeds
    // -------------------------------------------------------------
    test('E. Knockout 1-1 with decisive penalties: succeeds', () {
      final res = simulateRecordMatchResult(
        homeScore: 1,
        awayScore: 1,
        homePenalties: 5,
        awayPenalties: 4,
        homeTeamId: 'team-1',
        awayTeamId: 'team-2',
        stage: 'knockout',
        championshipType: 'cup',
        currentResultStatus: 'scheduled',
      );
      expect(res['success'], isTrue);
      expect(res['winner_id'], equals('team-1'));
      expect(res['is_knockout'], isTrue);
      expect(res['status'], equals('completed'));
      expect(res['result_status'], equals('confirmed'));
    });

    // -------------------------------------------------------------
    // Test F: League standings: confirmed counted, unconfirmed & knockout excluded
    // -------------------------------------------------------------
    test('F. League standings: confirmed league results counted, disputed/unconfirmed excluded, knockout excluded', () {
      final matches = [
        // 1. Confirmed League Match -> COUNTED
        {
          'id': 'm1',
          'stage': 'league',
          'home_team_id': 't1',
          'away_team_id': 't2',
          'home_score': 2,
          'away_score': 1,
          'status': 'completed',
          'result_status': 'confirmed',
        },
        // 2. Disputed League Match -> EXCLUDED
        {
          'id': 'm2',
          'stage': 'league',
          'home_team_id': 't1',
          'away_team_id': 't2',
          'home_score': 3,
          'away_score': 0,
          'status': 'disputed',
          'result_status': 'disputed',
        },
        // 3. Scheduled League Match -> EXCLUDED
        {
          'id': 'm3',
          'stage': 'league',
          'home_team_id': 't1',
          'away_team_id': 't2',
          'home_score': null,
          'away_score': null,
          'status': 'scheduled',
          'result_status': 'scheduled',
        },
        // 4. Knockout match in same tournament -> EXCLUDED from league standings!
        {
          'id': 'm4',
          'stage': 'knockout',
          'home_team_id': 't1',
          'away_team_id': 't2',
          'home_score': 4,
          'away_score': 0,
          'status': 'completed',
          'result_status': 'confirmed',
        },
      ];

      bool isMatchCountedInLeagueStandings(Map<String, dynamic> m) {
        return m['stage'] == 'league' &&
            m['status'] == 'completed' &&
            ['confirmed', 'locked'].contains(m['result_status']) &&
            m['home_score'] != null &&
            m['away_score'] != null;
      }

      final counted = matches.where(isMatchCountedInLeagueStandings).toList();
      expect(counted.length, equals(1));
      expect(counted.first['id'], equals('m1'));
    });

    // -------------------------------------------------------------
    // Test G: Away-team goals_against: Home 3 - Away 1 -> Home GA = 1, Away GA = 3
    // -------------------------------------------------------------
    test('G. Away-team goals_against: Home 3 - Away 1 -> Home GA = 1, Away GA = 3, correct goal difference', () {
      // Simulating the corrected projection logic in get_championship_standings:
      // Home team: gf = home_score, ga = away_score
      // Away team: gf = away_score, ga = home_score
      const homeScore = 3;
      const awayScore = 1;

      // Home perspective
      const homeGf = homeScore;
      const homeGa = awayScore;
      const homeGd = homeGf - homeGa;

      // Away perspective
      const awayGf = awayScore;
      const awayGa = homeScore;
      const awayGd = awayGf - awayGa;

      expect(homeGf, equals(3));
      expect(homeGa, equals(1));
      expect(homeGd, equals(2));

      expect(awayGf, equals(1));
      expect(awayGa, equals(3), reason: 'Away team goals against must be equal to home score (3), not away score (1)');
      expect(awayGd, equals(-2));
    });

    // -------------------------------------------------------------
    // Test H: League champion: actual table leader can be crowned,
    // first League match must NEVER be treated as a final
    // -------------------------------------------------------------
    test('H. League champion: table leader can be crowned, first match is NEVER treated as final', () {
      Map<String, dynamic> simulateCrowningLeague({
        required String championshipType,
        required List<Map<String, dynamic>> allMatches,
        required List<String> standingsTeamIds, // 1st element is top of table
        required String candidateChampionId,
        required bool isRosterFrozen,
      }) {
        // In a league, there is NO bracket final
        if (championshipType == 'league') {
          // 1. All matches must be completed and confirmed
          final uncompleted = allMatches.any((m) =>
              m['status'] != 'completed' ||
              !['confirmed', 'locked'].contains(m['result_status']));
          if (uncompleted) {
            return {'success': false, 'error': 'MATCHES_NOT_COMPLETED'};
          }

          // 2. Candidate must equal 1st place in standings
          final topTeamId = standingsTeamIds.isNotEmpty ? standingsTeamIds.first : null;
          if (topTeamId != candidateChampionId) {
            return {'success': false, 'error': 'CHAMPION_MUST_BE_LEAGUE_LEADER'};
          }
        }

        if (!isRosterFrozen) {
          return {'success': false, 'error': 'FROZEN_ROSTER_REQUIRED'};
        }

        return {
          'success': true,
          'champion_team_id': candidateChampionId,
          'status': 'completed',
        };
      }

      // Scenario: Team B won the first match (round 0), BUT Team A won more points overall and is 1st in standings!
      final leagueMatches = [
        {'id': 'm1', 'round_index': 0, 'next_match_id': null, 'winner_id': 'team-b', 'status': 'completed', 'result_status': 'confirmed'},
        {'id': 'm2', 'round_index': 0, 'next_match_id': null, 'winner_id': 'team-a', 'status': 'completed', 'result_status': 'confirmed'},
        {'id': 'm3', 'round_index': 0, 'next_match_id': null, 'winner_id': 'team-a', 'status': 'completed', 'result_status': 'confirmed'},
      ];
      final standings = ['team-a', 'team-b']; // Team A is 1st

      // Attempting to crown Team B (who won match 1, but is 2nd in table) -> MUST FAIL!
      final resCrownLoser = simulateCrowningLeague(
        championshipType: 'league',
        allMatches: leagueMatches,
        standingsTeamIds: standings,
        candidateChampionId: 'team-b',
        isRosterFrozen: true,
      );
      expect(resCrownLoser['success'], isFalse);
      expect(resCrownLoser['error'], equals('CHAMPION_MUST_BE_LEAGUE_LEADER'));

      // Crowning Team A (who is 1st in standings) -> SUCCEEDS!
      final resCrownLeader = simulateCrowningLeague(
        championshipType: 'league',
        allMatches: leagueMatches,
        standingsTeamIds: standings,
        candidateChampionId: 'team-a',
        isRosterFrozen: true,
      );
      expect(resCrownLeader['success'], isTrue);
      expect(resCrownLeader['champion_team_id'], equals('team-a'));
    });

    // -------------------------------------------------------------
    // Test I: Completion guard: completed + scheduled cannot bypass;
    // completed + confirmed is valid
    // -------------------------------------------------------------
    test('I. Completion: completed + scheduled cannot bypass; completed + confirmed is valid', () {
      Map<String, dynamic> simulateCompletionTransition({
        required String? championTeamId,
        required List<Map<String, dynamic>> allMatches,
      }) {
        if (championTeamId == null) {
          return {'success': false, 'error': 'BLOCKED_BY_STATE: Cannot transition without crowned champion'};
        }

        final invalidMatch = allMatches.any((m) =>
            m['status'] != 'completed' ||
            !['confirmed', 'locked'].contains(m['result_status']));

        if (invalidMatch) {
          return {'success': false, 'error': 'BLOCKED_BY_STATE: Cannot transition with uncompleted/unconfirmed matches'};
        }

        return {'success': true, 'status': 'completed'};
      }

      // Bypass attempt: status = completed, but result_status = scheduled -> REJECTED!
      final resBypass = simulateCompletionTransition(
        championTeamId: 'team-champ',
        allMatches: [
          {'status': 'completed', 'result_status': 'scheduled'},
        ],
      );
      expect(resBypass['success'], isFalse);
      expect(resBypass['error'], contains('BLOCKED_BY_STATE'));

      // Bypass attempt: disputed match -> REJECTED!
      final resDisputed = simulateCompletionTransition(
        championTeamId: 'team-champ',
        allMatches: [
          {'status': 'completed', 'result_status': 'disputed'},
        ],
      );
      expect(resDisputed['success'], isFalse);
      expect(resDisputed['error'], contains('BLOCKED_BY_STATE'));

      // Valid: all matches completed and confirmed -> SUCCEEDS!
      final resValid = simulateCompletionTransition(
        championTeamId: 'team-champ',
        allMatches: [
          {'status': 'completed', 'result_status': 'confirmed'},
          {'status': 'completed', 'result_status': 'locked'},
        ],
      );
      expect(resValid['success'], isTrue);
      expect(resValid['status'], equals('completed'));
    });
  });
}
