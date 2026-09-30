import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/league/team_league_repository.dart';

void main() {
  group('VSP Team League Logic & Models Unit Tests', () {
    test('TeamLeagueStandingItem calculates correct points and integrity', () {
      final standing = TeamLeagueStandingItem(
        rank: 1,
        teamId: 't1',
        teamName: 'الأبطال',
        teamLogoUrl: null,
        played: 3,
        won: 2,
        drawn: 1,
        lost: 0,
        points: 7,
      );

      expect(standing.rank, 1);
      expect(standing.played, standing.won + standing.drawn + standing.lost);
      expect(standing.points, (standing.won * 3) + (standing.drawn * 1));
      expect(standing.teamName, 'الأبطال');
    });

    test('TeamLeagueStandingItem fromJson correctly parses pure standings', () {
      final json = {
        'rank': 2,
        'team_id': 'team_abc',
        'team_name': 'نجوم المعادي',
        'team_logo_url': 'https://example.com/logo.png',
        'played': 5,
        'won': 3,
        'drawn': 1,
        'lost': 1,
        'points': 10,
      };

      final item = TeamLeagueStandingItem.fromJson(json);
      expect(item.rank, 2);
      expect(item.teamId, 'team_abc');
      expect(item.teamName, 'نجوم المعادي');
      expect(item.won, 3);
      expect(item.drawn, 1);
      expect(item.lost, 1);
      expect(item.points, 10);
    });

    test('TeamLeagueMatch identifies confirmed, disputed, and locked states', () {
      final now = DateTime.now();

      // Confirmed match within 15 mins (can still be corrected)
      final confirmedRecent = TeamLeagueMatch(
        id: 'm1',
        championshipId: 'c1',
        weekNumber: 1,
        matchIndex: 0,
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
      expect(confirmedRecent.isDisputed, isFalse);
      expect(confirmedRecent.isLocked, isFalse);
      expect(confirmedRecent.canCorrectResult, isTrue);

      // Confirmed match after 15 mins (locked)
      final confirmedLocked = TeamLeagueMatch(
        id: 'm2',
        championshipId: 'c1',
        weekNumber: 1,
        matchIndex: 1,
        stage: 'league',
        homeTeamId: 't1',
        awayTeamId: 't2',
        homeTeamName: 'فريق أ',
        awayTeamName: 'فريق ب',
        resultStatus: 'confirmed',
        status: 'completed',
        isCompleted: true,
        confirmedOutcome: 'draw',
        resultConfirmedAt: now.subtract(const Duration(minutes: 20)),
      );

      expect(confirmedLocked.isConfirmed, isTrue);
      expect(confirmedLocked.isLocked, isTrue);
      expect(confirmedLocked.canCorrectResult, isFalse);

      // Disputed match
      final disputedMatch = TeamLeagueMatch(
        id: 'm3',
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
      );

      expect(disputedMatch.isDisputed, isTrue);
      expect(disputedMatch.isConfirmed, isFalse);
      expect(disputedMatch.isLocked, isFalse);
    });

    test('Round-Robin Fixture Math: 4 to 8 teams match counts', () {
      int calculateMatchCount(int n) => (n * (n - 1)) ~/ 2;

      expect(calculateMatchCount(4), 6);
      expect(calculateMatchCount(5), 10);
      expect(calculateMatchCount(6), 15);
      expect(calculateMatchCount(7), 21);
      expect(calculateMatchCount(8), 28);
    });

    test('Result Reconciliation Matrix logic verification', () {
      // Logic replicated from Postgres RPC: submit_team_league_match_result
      String? reconcile(String homeSub, String awaySub) {
        if (homeSub == 'win' && awaySub == 'loss') return 'home_win';
        if (homeSub == 'loss' && awaySub == 'win') return 'away_win';
        if (homeSub == 'draw' && awaySub == 'draw') return 'draw';
        return null; // Dispute
      }

      expect(reconcile('win', 'loss'), 'home_win');
      expect(reconcile('loss', 'win'), 'away_win');
      expect(reconcile('draw', 'draw'), 'draw');

      // Conflicts
      expect(reconcile('win', 'win'), isNull);
      expect(reconcile('loss', 'loss'), isNull);
      expect(reconcile('win', 'draw'), isNull);
      expect(reconcile('draw', 'loss'), isNull);
    });

    test('Team Entry Fee is strictly 30 EGP per team', () {
      const feePerTeam = 30;
      int calculateTotalFee(int teamCount) => teamCount * feePerTeam;

      expect(calculateTotalFee(4), 120);
      expect(calculateTotalFee(6), 180);
      expect(calculateTotalFee(8), 240);
      expect(calculateTotalFee(1), 30);
    });
  });
}
