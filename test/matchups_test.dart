import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/matchup_repository.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('⚔️ VSP Matchups Feature — Unit & Logic Tests', () {
    test('1. Verify Points calculation rule: (3 * Wins) + (1 * Draws)', () {
      final repo = MatchupRepository();

      final teams = [
        MatchupTeam(
          id: 'mt_1',
          bookingId: 'bk_001',
          teamId: 'team_a',
          teamName: 'Ahly Stars',
          addedByUserId: 'user_1',
          joinedAt: DateTime.now(),
        ),
        MatchupTeam(
          id: 'mt_2',
          bookingId: 'bk_001',
          teamId: 'team_b',
          teamName: 'Zamalek Knights',
          addedByUserId: 'user_2',
          joinedAt: DateTime.now(),
        ),
        MatchupTeam(
          id: 'mt_3',
          bookingId: 'bk_001',
          teamId: 'team_c',
          teamName: 'Pyramids FC',
          addedByUserId: 'user_3',
          joinedAt: DateTime.now(),
        ),
      ];

      final results = [
        // Team A vs Team B -> Team A wins (A: 3 pts, B: 0 pts)
        MatchupResult(
          id: 'r_1',
          bookingId: 'bk_001',
          teamAId: 'team_a',
          teamBId: 'team_b',
          outcome: 'team_a_win',
          recordedBy: 'user_1',
          createdAt: DateTime.now(),
        ),
        // Team A vs Team C -> Draw (A: 4 pts, C: 1 pt)
        MatchupResult(
          id: 'r_2',
          bookingId: 'bk_001',
          teamAId: 'team_a',
          teamBId: 'team_c',
          outcome: 'draw',
          recordedBy: 'user_1',
          createdAt: DateTime.now(),
        ),
        // Team B vs Team C -> Team C wins (C: 4 pts, B: 0 pts)
        MatchupResult(
          id: 'r_3',
          bookingId: 'bk_001',
          teamAId: 'team_b',
          teamBId: 'team_c',
          outcome: 'team_b_win', // team_b_win means second team (team_c) won
          recordedBy: 'user_1',
          createdAt: DateTime.now(),
        ),
      ];

      final standings = repo.calculateStandings(teams, results);

      expect(standings.length, 3);

      // Leader should have 4 points (Team A: 1 Win, 1 Draw = 4 pts)
      expect(standings[0].teamId, 'team_a');
      expect(standings[0].points, 4);
      expect(standings[0].wins, 1);
      expect(standings[0].draws, 1);
      expect(standings[0].losses, 0);
      expect(standings[0].matchesPlayed, 2);

      // Team C has 4 points (1 Win, 1 Draw = 4 pts)
      expect(standings[1].teamId, 'team_c');
      expect(standings[1].points, 4);
      expect(standings[1].wins, 1);
      expect(standings[1].draws, 1);
      expect(standings[1].losses, 0);

      // Team B has 0 points (0 Wins, 0 Draws, 2 Losses = 0 pts)
      expect(standings[2].teamId, 'team_b');
      expect(standings[2].points, 0);
      expect(standings[2].wins, 0);
      expect(standings[2].losses, 2);
    });

    test('2. Verify BookingType.matchup serialization and fromMap', () {
      final map = {
        'id': 'bk_test_123',
        'stadiumId': 'std_01',
        'stadiumName': 'Camp Nou',
        'ownerId': 'own_01',
        'bookingType': 'matchup',
        'startTime': DateTime.now().toIso8601String(),
        'endTime': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        'totalPrice': 200.0,
        'status': 'confirmed',
      };

      final booking = Booking.fromMap(map);
      expect(booking.bookingType, BookingType.matchup);
    });

    test('3. Verify TeamHeadToHead total matches calculation', () {
      final h2h = TeamHeadToHead(
        teamAId: 'team_a',
        teamBId: 'team_b',
        teamAWins: 5,
        teamBWins: 3,
        draws: 2,
        updatedAt: DateTime.now(),
      );

      expect(h2h.totalMatches, 10);
    });
  });
}
