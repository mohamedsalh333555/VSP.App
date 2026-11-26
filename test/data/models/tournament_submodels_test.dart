import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models/tournament_match.dart';

void main() {
  group('Tournament Sub-models', () {
    test('GoalItem and TournamentMatch serialize and report status accurately', () {
      final goal = GoalItem(
        id: 'g1',
        teamId: 't1',
        playerName: 'Zizo',
        isOwnGoal: false,
      );

      expect(goal.playerName, equals('Zizo'));
      final goalMap = goal.toMap();
      expect(GoalItem.fromMap(goalMap).playerName, equals('Zizo'));

      final match = TournamentMatch(
        id: 'm1',
        championshipId: 'c1',
        roundIndex: 0,
        matchIndex: 0,
        homeTeamId: 't1',
        homeTeamName: 'Ahly',
        awayTeamId: 't2',
        awayTeamName: 'Zamalek',
        homeScore: 2,
        awayScore: 1,
        winnerId: 't1',
        goalDetails: [goal],
      );

      expect(match.isCompleted, isTrue);
      expect(match.isReady, isTrue);
      expect(match.roundLabel, equals('Final'));

      final matchMap = match.toMap();
      final revivedMatch = TournamentMatch.fromMap(matchMap, 'm1');
      expect(revivedMatch.id, equals('m1'));
      expect(revivedMatch.homeScore, equals(2));
      expect(revivedMatch.winnerId, equals('t1'));
      expect(revivedMatch.goalDetails.length, equals(1));
    });
  });
}
