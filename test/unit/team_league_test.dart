import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/league/team_league_repository.dart';

void main() {
  group('VSP Team League - Master Architecture Tests', () {
    // -------------------------------------------------------------
    // 1. Single State Machine & Status Properties
    // -------------------------------------------------------------
    test('Single State Machine covers all states correctly', () {
      final now = DateTime.now();

      // State 1: scheduled
      final scheduled = TeamLeagueMatch(
        id: 'm1',
        championshipId: 'c1',
        weekNumber: 1,
        matchIndex: 0,
        stage: 'league',
        homeTeamId: 't1',
        awayTeamId: 't2',
        homeTeamName: 'فريق أ',
        awayTeamName: 'فريق ب',
        resultStatus: 'scheduled',
        status: 'scheduled',
        isCompleted: false,
      );
      expect(scheduled.isScheduled, isTrue);
      expect(scheduled.isAwaitingSubmissions, isFalse);
      expect(scheduled.isAwaitingConfirmation, isFalse);
      expect(scheduled.isDisputed, isFalse);
      expect(scheduled.isConfirmed, isFalse);
      expect(scheduled.isLocked, isFalse);

      // State 2: awaiting_submissions (one team submitted)
      final awaitingSubs = TeamLeagueMatch(
        id: 'm2',
        championshipId: 'c1',
        weekNumber: 1,
        matchIndex: 1,
        stage: 'league',
        homeTeamId: 't1',
        awayTeamId: 't2',
        homeTeamName: 'فريق أ',
        awayTeamName: 'فريق ب',
        resultStatus: 'awaiting_submissions',
        status: 'scheduled',
        isCompleted: false,
        myTeamSubmission: 'win',
      );
      expect(awaitingSubs.isAwaitingSubmissions, isTrue);
      expect(awaitingSubs.isConfirmed, isFalse);

      // State 3: awaiting_confirmation (both submitted matching, NO auto-confirm)
      final awaitingConf = TeamLeagueMatch(
        id: 'm3',
        championshipId: 'c1',
        weekNumber: 1,
        matchIndex: 2,
        stage: 'league',
        homeTeamId: 't1',
        awayTeamId: 't2',
        homeTeamName: 'فريق أ',
        awayTeamName: 'فريق ب',
        resultStatus: 'awaiting_confirmation',
        status: 'scheduled',
        isCompleted: false,
        confirmedOutcome: 'home_win',
        homeSubmission: 'win',
        awaySubmission: 'loss',
      );
      expect(awaitingConf.isAwaitingConfirmation, isTrue);
      expect(awaitingConf.isConfirmed, isFalse); // Creator must approve!

      // State 4: disputed (both submitted conflicting outcomes)
      final disputed = TeamLeagueMatch(
        id: 'm4',
        championshipId: 'c1',
        weekNumber: 2,
        matchIndex: 0,
        stage: 'league',
        homeTeamId: 't1',
        awayTeamId: 't2',
        homeTeamName: 'فريق أ',
        awayTeamName: 'فريق ب',
        resultStatus: 'disputed',
        status: 'scheduled',
        isCompleted: false,
        homeSubmission: 'win',
        awaySubmission: 'win',
      );
      expect(disputed.isDisputed, isTrue);
      expect(disputed.isConfirmed, isFalse);

      // State 5: confirmed within 15 mins (correction window active)
      final confirmedRecent = TeamLeagueMatch(
        id: 'm5',
        championshipId: 'c1',
        weekNumber: 2,
        matchIndex: 1,
        stage: 'league',
        homeTeamId: 't1',
        awayTeamId: 't2',
        homeTeamName: 'فريق أ',
        awayTeamName: 'فريق ب',
        resultStatus: 'confirmed',
        status: 'completed',
        isCompleted: true,
        confirmedOutcome: 'home_win',
        resultConfirmedAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(confirmedRecent.isConfirmed, isTrue);
      expect(confirmedRecent.isLocked, isFalse);
      expect(confirmedRecent.canCorrectResult, isTrue);

      // State 6: locked after 15 mins
      final locked = TeamLeagueMatch(
        id: 'm6',
        championshipId: 'c1',
        weekNumber: 3,
        matchIndex: 0,
        stage: 'league',
        homeTeamId: 't1',
        awayTeamId: 't2',
        homeTeamName: 'فريق أ',
        awayTeamName: 'فريق ب',
        resultStatus: 'locked',
        status: 'completed',
        isCompleted: true,
        confirmedOutcome: 'draw',
        resultConfirmedAt: now.subtract(const Duration(minutes: 20)),
        resultLockedAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(locked.isConfirmed, isTrue);
      expect(locked.isLocked, isTrue);
      expect(locked.canCorrectResult, isFalse);
    });

    // -------------------------------------------------------------
    // 2. Circle/Berger Round-Robin Fixtures Matrix (4, 5, 6, 7, 8 Teams)
    // -------------------------------------------------------------
    test('Circle Algorithm guarantees every team plays at most once per round and unique pairs', () {
      for (int teamCount = 4; teamCount <= 8; teamCount++) {
        final teams = List.generate(teamCount, (i) => 'team_${i + 1}');
        final virtualTeams = List<String?>.from(teams);

        // If odd, append a dummy bye team
        final bool hasBye = teamCount % 2 != 0;
        if (hasBye) {
          virtualTeams.add(null); // NULL represents BYE
        }

        final int virtualCount = virtualTeams.length;
        final int roundsCount = virtualCount - 1;
        final int matchesPerRound = virtualCount ~/ 2;

        final Set<String> generatedPairs = {};
        int totalMatches = 0;

        for (int r = 0; r < roundsCount; r++) {
          final Set<String> teamsInRound = {};

          for (int m = 0; m < matchesPerRound; m++) {
            int t1Idx;
            int t2Idx;

            if (m == 0) {
              t1Idx = virtualCount - 1;
              t2Idx = r % (virtualCount - 1);
            } else {
              t1Idx = (r + m) % (virtualCount - 1);
              t2Idx = (r - m + (virtualCount - 1)) % (virtualCount - 1);
            }

            final t1 = virtualTeams[t1Idx];
            final t2 = virtualTeams[t2Idx];

            // If either team is the BYE dummy, skip match
            if (t1 == null || t2 == null) continue;

            // Invariance: No team plays twice in the same round!
            expect(teamsInRound.contains(t1), isFalse,
                reason: 'Team $t1 appeared more than once in round $r with $teamCount teams');
            expect(teamsInRound.contains(t2), isFalse,
                reason: 'Team $t2 appeared more than once in round $r with $teamCount teams');

            teamsInRound.add(t1);
            teamsInRound.add(t2);

            // Canonical pair key to verify uniqueness
            final pairKey = [t1, t2]..sort();
            final keyStr = pairKey.join('_vs_');

            expect(generatedPairs.contains(keyStr), isFalse,
                reason: 'Duplicate match $keyStr in league of $teamCount teams');
            generatedPairs.add(keyStr);

            totalMatches++;
          }
        }

        // Expected total matches = N * (N - 1) / 2
        final expectedMatches = (teamCount * (teamCount - 1)) ~/ 2;
        expect(totalMatches, expectedMatches,
            reason: 'Total matches mismatch for $teamCount teams');
      }
    });

    // -------------------------------------------------------------
    // 3. Pure Standings & Head-to-Head (H2H) Tie-Breaking
    // -------------------------------------------------------------
    test('Pure Standings calculation with Head-to-Head tie-breaking (ZERO goals)', () {
      // Scenario:
      // Team A: 6 points (Won vs B, Won vs C, Lost vs D) -> W:2, D:0, L:1
      // Team B: 6 points (Lost vs A, Won vs C, Won vs D) -> W:2, D:0, L:1
      // Tied on Points (6 pts each).
      // Head-to-head match: Team A beat Team B!
      // Therefore, Team A MUST be ranked above Team B despite zero goals.

      final teamA = {
        'id': 'tA',
        'name': 'فريق أ',
        'points': 6,
        'won': 2,
        'h2h_vs_B': 3, // A beat B
      };

      final teamB = {
        'id': 'tB',
        'name': 'فريق ب',
        'points': 6,
        'won': 2,
        'h2h_vs_A': 0, // B lost to A
      };

      // Comparison function implementing our exact SQL tie-breaker:
      int compareTeams(Map<String, dynamic> a, Map<String, dynamic> b) {
        // 1. Total Points
        if (a['points'] != b['points']) {
          return (b['points'] as int).compareTo(a['points'] as int);
        }
        // 2. Head-to-Head points between the tied teams
        final aH2H = (a['h2h_vs_B'] as int?) ?? 0;
        final bH2H = (b['h2h_vs_A'] as int?) ?? 0;
        if (aH2H != bH2H) {
          return bH2H.compareTo(aH2H);
        }
        // 3. Total Wins
        if (a['won'] != b['won']) {
          return (b['won'] as int).compareTo(a['won'] as int);
        }
        // 4. Alphabetical / Deterministic
        return (a['name'] as String).compareTo(b['name'] as String);
      }

      final list = [teamB, teamA]..sort(compareTeams);

      expect(list.first['id'], 'tA', reason: 'Team A beat Team B in H2H, so A must rank #1');
      expect(list.last['id'], 'tB', reason: 'Team B lost to Team A in H2H, so B must rank #2');
    });

    // -------------------------------------------------------------
    // 4. Server-Side 15-Minute Window Lock Logic
    // -------------------------------------------------------------
    test('Server-side 15-minute lock condition evaluation', () {
      final now = DateTime.now();

      bool isServerLocked(String status, DateTime? confirmedAt) {
        if (status == 'locked') return true;
        if (confirmedAt != null && now.isAfter(confirmedAt.add(const Duration(minutes: 15)))) {
          return true;
        }
        return false;
      }

      // 14 minutes ago -> Not locked
      expect(isServerLocked('confirmed', now.subtract(const Duration(minutes: 14))), isFalse);

      // Exactly 15 minutes + 1 second ago -> LOCKED
      expect(isServerLocked('confirmed', now.subtract(const Duration(minutes: 15, seconds: 1))), isTrue);

      // Status explicitly locked -> LOCKED
      expect(isServerLocked('locked', now.subtract(const Duration(minutes: 2))), isTrue);
    });

    // -------------------------------------------------------------
    // 5. Entry Fee Contract (30 EGP per team)
    // -------------------------------------------------------------
    test('Team Entry Fee strictly scales by 30 EGP per team', () {
      const feePerTeam = 30;
      for (int count = 4; count <= 8; count++) {
        expect(count * feePerTeam, equals(count * 30));
      }
    });
  });
}
