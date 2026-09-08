import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models/vsp_1v1_player.dart';
import 'package:vsp_application/data/models/tournament_match.dart';

void main() {
  group('Tournament Sub-models', () {
    test('VSP1v1Player serialization and mock standings work properly', () {
      final player = VSP1v1Player(
        id: 'p1',
        name: 'Kareem',
        avatarUrl: 'https://example.com/kareem.jpg',
        totalPoints: 120,
        skillPoints: 80,
        goals: 15,
        tackles: 9,
        titles: 2,
        rank: 1,
      );

      final map = player.toMap();
      expect(map['name'], equals('Kareem'));
      expect(map['totalPoints'], equals(120));
      expect(map['rank'], equals(1));

      final revived = VSP1v1Player.fromMap(map, 'p1');
      expect(revived.id, equals('p1'));
      expect(revived.name, equals('Kareem'));
      expect(revived.titles, equals(2));

      final mockList = VSP1v1Player.getMockStandings();
      expect(mockList, isNotEmpty);
      expect(mockList.first.rank, equals(1));
    });

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
