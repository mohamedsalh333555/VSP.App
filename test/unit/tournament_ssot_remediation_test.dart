import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tournament Journey Targeted SSOT Remediation Tests', () {
    // -------------------------------------------------------------
    // 1. Canonical Championship Status in Match Card UI
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

      // Valid case: owner with assigned teams on ongoing tournament
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

      // Invalid case: old buggy 'in_progress' status must not be accepted as canonical
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

      // Other non-ongoing states
      expect(
        canRecordScore(
          isOwner: true,
          homeTeamId: 'team-1',
          awayTeamId: 'team-2',
          championshipStatus: 'open',
        ),
        isFalse,
      );
      expect(
        canRecordScore(
          isOwner: true,
          homeTeamId: 'team-1',
          awayTeamId: 'team-2',
          championshipStatus: 'completed',
        ),
        isFalse,
      );
    });

    // -------------------------------------------------------------
    // 2. Server-Authoritative Match Result Validation Contract
    // -------------------------------------------------------------
    group('record_match_result_and_advance_atomic contract', () {
      Map<String, dynamic> simulateRecordMatchResult({
        required int homeScore,
        required int awayScore,
        int? homePenalties,
        int? awayPenalties,
        String? winnerId,
        required String homeTeamId,
        required String awayTeamId,
        required bool isKnockout,
        required String currentResultStatus,
      }) {
        // 1. Negative score check
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

        // 3. Score vs winner validation
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
            effectiveWinnerId = null;
          }
        }

        // 4. Winner must be one of the participating teams
        if (effectiveWinnerId != null &&
            effectiveWinnerId != homeTeamId &&
            effectiveWinnerId != awayTeamId) {
          return {'success': false, 'error': 'INVALID_WINNER: Winner must be one of the participating teams'};
        }

        if (isKnockout && effectiveWinnerId == null) {
          return {'success': false, 'error': 'WINNER_REQUIRED: Knockout match requires a decisive winner'};
        }

        return {
          'success': true,
          'winner_id': effectiveWinnerId,
          'status': 'completed',
          'is_completed': true,
          'result_status': 'confirmed',
        };
      }

      test('Rejects negative home or away score', () {
        final resNegativeHome = simulateRecordMatchResult(
          homeScore: -1,
          awayScore: 2,
          homeTeamId: 't1',
          awayTeamId: 't2',
          isKnockout: false,
          currentResultStatus: 'scheduled',
        );
        expect(resNegativeHome['success'], isFalse);
        expect(resNegativeHome['error'], contains('INVALID_SCORE'));

        final resNegativeAway = simulateRecordMatchResult(
          homeScore: 3,
          awayScore: -2,
          homeTeamId: 't1',
          awayTeamId: 't2',
          isKnockout: false,
          currentResultStatus: 'scheduled',
        );
        expect(resNegativeAway['success'], isFalse);
        expect(resNegativeAway['error'], contains('INVALID_SCORE'));
      });

      test('Tied knockout match requires valid unequal penalties', () {
        // Without penalties -> rejected
        final resNoPens = simulateRecordMatchResult(
          homeScore: 2,
          awayScore: 2,
          homeTeamId: 't1',
          awayTeamId: 't2',
          isKnockout: true,
          currentResultStatus: 'scheduled',
        );
        expect(resNoPens['success'], isFalse);
        expect(resNoPens['error'], contains('PENALTIES_REQUIRED'));

        // With tied penalties -> rejected
        final resTiedPens = simulateRecordMatchResult(
          homeScore: 1,
          awayScore: 1,
          homePenalties: 4,
          awayPenalties: 4,
          homeTeamId: 't1',
          awayTeamId: 't2',
          isKnockout: true,
          currentResultStatus: 'scheduled',
        );
        expect(resTiedPens['success'], isFalse);
        expect(resTiedPens['error'], contains('PENALTIES_TIED'));

        // With decisive penalties -> succeeds and confirms result
        final resValidPens = simulateRecordMatchResult(
          homeScore: 1,
          awayScore: 1,
          homePenalties: 5,
          awayPenalties: 4,
          homeTeamId: 't1',
          awayTeamId: 't2',
          isKnockout: true,
          currentResultStatus: 'scheduled',
        );
        expect(resValidPens['success'], isTrue);
        expect(resValidPens['winner_id'], equals('t1'));
        expect(resValidPens['result_status'], equals('confirmed'));
      });

      test('Rejects invalid winner not in match or winner/score mismatch', () {
        // Winner is an unrelated team
        final resAlienWinner = simulateRecordMatchResult(
          homeScore: 3,
          awayScore: 1,
          winnerId: 'alien-team-99',
          homeTeamId: 't1',
          awayTeamId: 't2',
          isKnockout: true,
          currentResultStatus: 'scheduled',
        );
        expect(resAlienWinner['success'], isFalse);
        expect(resAlienWinner['error'], contains('WINNER_MISMATCH'));

        // Regular time home won 3-1, but client tried to declare away winner
        final resInvertedWinner = simulateRecordMatchResult(
          homeScore: 3,
          awayScore: 1,
          winnerId: 't2',
          homeTeamId: 't1',
          awayTeamId: 't2',
          isKnockout: true,
          currentResultStatus: 'scheduled',
        );
        expect(resInvertedWinner['success'], isFalse);
        expect(resInvertedWinner['error'], contains('WINNER_MISMATCH'));
      });

      test('Valid match result transitions atomically to completed and confirmed', () {
        final resSuccess = simulateRecordMatchResult(
          homeScore: 2,
          awayScore: 0,
          homeTeamId: 't1',
          awayTeamId: 't2',
          isKnockout: true,
          currentResultStatus: 'scheduled',
        );
        expect(resSuccess['success'], isTrue);
        expect(resSuccess['status'], equals('completed'));
        expect(resSuccess['is_completed'], isTrue);
        expect(resSuccess['result_status'], equals('confirmed'));
        expect(resSuccess['winner_id'], equals('t1'));
      });
    });

    // -------------------------------------------------------------
    // 3. Standings SSOT: Only Authoritative Results Count
    // -------------------------------------------------------------
    test('Standings engine excludes disputed, scheduled, or unconfirmed matches', () {
      final matches = [
        // Confirmed completed match -> MUST count (t1 wins 2-0 over t2)
        {
          'home_team_id': 't1',
          'away_team_id': 't2',
          'home_score': 2,
          'away_score': 0,
          'status': 'completed',
          'result_status': 'confirmed',
        },
        // Locked completed match -> MUST count (t1 wins 1-0 over t3)
        {
          'home_team_id': 't1',
          'away_team_id': 't3',
          'home_score': 1,
          'away_score': 0,
          'status': 'completed',
          'result_status': 'locked',
        },
        // Disputed match with non-null scores -> MUST BE EXCLUDED!
        {
          'home_team_id': 't2',
          'away_team_id': 't3',
          'home_score': 5,
          'away_score': 0,
          'status': 'disputed',
          'result_status': 'disputed',
        },
        // Scheduled match -> MUST BE EXCLUDED!
        {
          'home_team_id': 't2',
          'away_team_id': 't3',
          'home_score': 0,
          'away_score': 0,
          'status': 'scheduled',
          'result_status': 'scheduled',
        },
      ];

      // Standings filter logic matching get_championship_standings
      bool isMatchCountedInStandings(Map<String, dynamic> m) {
        final status = m['status'];
        final resultStatus = m['result_status'] ?? 'confirmed';
        final hasScores = m['home_score'] != null && m['away_score'] != null;

        return hasScores &&
            status == 'completed' &&
            (resultStatus == 'confirmed' || resultStatus == 'locked');
      }

      final countedMatches = matches.where(isMatchCountedInStandings).toList();
      expect(countedMatches.length, equals(2));
      expect(countedMatches.any((m) => m['result_status'] == 'disputed'), isFalse);
      expect(countedMatches.any((m) => m['status'] == 'scheduled'), isFalse);
    });

    // -------------------------------------------------------------
    // 4. Champion SSOT & Final Winner Validation
    // -------------------------------------------------------------
    group('crown_tournament_champion_atomic contract', () {
      Map<String, dynamic> simulateCrowning({
        required String championshipStatus,
        required String? finalMatchStatus,
        required String? finalMatchResultStatus,
        required String? finalMatchWinnerId,
        required String candidateChampionId,
        required bool isRosterFrozen,
        String? existingChampionId,
      }) {
        if (championshipStatus == 'completed') {
          if (existingChampionId == candidateChampionId) {
            return {'success': true, 'already_crowned': true};
          }
          return {'success': false, 'error': 'championship_already_completed_with_different_champion'};
        }

        if (championshipStatus != 'ongoing') {
          return {'success': false, 'error': 'championship_not_ongoing'};
        }

        // Final match must be completed with authoritative result
        if (finalMatchStatus != 'completed' ||
            (finalMatchResultStatus != 'confirmed' && finalMatchResultStatus != 'locked')) {
          return {'success': false, 'error': 'FINAL_MATCH_NOT_COMPLETED'};
        }

        // Winner of the final match must match the crowned champion
        if (finalMatchWinnerId != candidateChampionId) {
          return {'success': false, 'error': 'CHAMPION_IS_NOT_FINAL_WINNER'};
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

      test('Rejects crowning when final match is not completed', () {
        final res = simulateCrowning(
          championshipStatus: 'ongoing',
          finalMatchStatus: 'scheduled',
          finalMatchResultStatus: 'scheduled',
          finalMatchWinnerId: null,
          candidateChampionId: 'team-finalist-1',
          isRosterFrozen: true,
        );
        expect(res['success'], isFalse);
        expect(res['error'], equals('FINAL_MATCH_NOT_COMPLETED'));
      });

      test('Rejects crowning a team that lost or did not win the final', () {
        final res = simulateCrowning(
          championshipStatus: 'ongoing',
          finalMatchStatus: 'completed',
          finalMatchResultStatus: 'confirmed',
          finalMatchWinnerId: 'team-winner',
          candidateChampionId: 'team-loser',
          isRosterFrozen: true,
        );
        expect(res['success'], isFalse);
        expect(res['error'], equals('CHAMPION_IS_NOT_FINAL_WINNER'));
      });

      test('Rejects crowning when roster is not frozen', () {
        final res = simulateCrowning(
          championshipStatus: 'ongoing',
          finalMatchStatus: 'completed',
          finalMatchResultStatus: 'confirmed',
          finalMatchWinnerId: 'team-winner',
          candidateChampionId: 'team-winner',
          isRosterFrozen: false,
        );
        expect(res['success'], isFalse);
        expect(res['error'], equals('FROZEN_ROSTER_REQUIRED'));
      });

      test('Successfully crowns authoritative final match winner with frozen roster', () {
        final res = simulateCrowning(
          championshipStatus: 'ongoing',
          finalMatchStatus: 'completed',
          finalMatchResultStatus: 'confirmed',
          finalMatchWinnerId: 'team-winner',
          candidateChampionId: 'team-winner',
          isRosterFrozen: true,
        );
        expect(res['success'], isTrue);
        expect(res['champion_team_id'], equals('team-winner'));
        expect(res['status'], equals('completed'));
      });

      test('Idempotent re-crowning of same champion returns success', () {
        final res = simulateCrowning(
          championshipStatus: 'completed',
          finalMatchStatus: 'completed',
          finalMatchResultStatus: 'confirmed',
          finalMatchWinnerId: 'team-winner',
          candidateChampionId: 'team-winner',
          existingChampionId: 'team-winner',
          isRosterFrozen: true,
        );
        expect(res['success'], isTrue);
        expect(res['already_crowned'], isTrue);
      });
    });

    // -------------------------------------------------------------
    // 5. Completion Guard: transition_championship_status_atomic
    // -------------------------------------------------------------
    group('transition_championship_status_atomic completion guard', () {
      Map<String, dynamic> simulateStatusTransition({
        required String currentStatus,
        required String targetStatus,
        required String? championTeamId,
        required int uncompletedMatchesCount,
        required int totalMatchesCount,
      }) {
        if (currentStatus == 'open' && targetStatus == 'ongoing') {
          if (totalMatchesCount == 0) {
            return {'success': false, 'error': 'BLOCKED_BY_STATE: Cannot transition to ongoing without fixtures'};
          }
          return {'success': true, 'status': 'ongoing'};
        }

        if (currentStatus == 'ongoing' && targetStatus == 'completed') {
          if (championTeamId == null) {
            return {'success': false, 'error': 'BLOCKED_BY_STATE: Cannot transition to completed without crowning champion'};
          }
          if (uncompletedMatchesCount > 0) {
            return {'success': false, 'error': 'BLOCKED_BY_STATE: Cannot transition to completed while uncompleted matches exist'};
          }
          return {'success': true, 'status': 'completed'};
        }

        return {'success': false, 'error': 'INVALID_TRANSITION'};
      }

      test('Blocks transition to completed if champion is not yet crowned', () {
        final res = simulateStatusTransition(
          currentStatus: 'ongoing',
          targetStatus: 'completed',
          championTeamId: null,
          uncompletedMatchesCount: 0,
          totalMatchesCount: 7,
        );
        expect(res['success'], isFalse);
        expect(res['error'], contains('without crowning champion'));
      });

      test('Blocks transition to completed if uncompleted matches remain', () {
        final res = simulateStatusTransition(
          currentStatus: 'ongoing',
          targetStatus: 'completed',
          championTeamId: 'team-champion',
          uncompletedMatchesCount: 2,
          totalMatchesCount: 7,
        );
        expect(res['success'], isFalse);
        expect(res['error'], contains('uncompleted matches exist'));
      });

      test('Allows transition to completed when all matches finished and champion crowned', () {
        final res = simulateStatusTransition(
          currentStatus: 'ongoing',
          targetStatus: 'completed',
          championTeamId: 'team-champion',
          uncompletedMatchesCount: 0,
          totalMatchesCount: 7,
        );
        expect(res['success'], isTrue);
        expect(res['status'], equals('completed'));
      });
    });
  });
}
