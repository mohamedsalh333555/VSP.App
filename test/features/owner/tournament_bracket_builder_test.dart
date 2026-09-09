import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models/team_models.dart';
import 'package:vsp_application/features/owner/widgets/tournament/tournament_bracket_builder.dart';

Team _team(String name) => Team(
      id: name,
      name: name,
      captainName: 'Captain',
      captainImageUrl: '',
      date: '2026-01-01',
      stadium: 'Test Stadium',
      pricePerPerson: 0,
      currentPlayers: 1,
      maxPlayers: 12,
    );

void main() {
  group('TournamentBracketBuilder.buildRounds', () {
    test('returns empty list for fewer than 2 teams', () {
      expect(TournamentBracketBuilder.buildRounds([]), isEmpty);
      expect(TournamentBracketBuilder.buildRounds([_team('A')]), isEmpty);
    });

    test('2 teams → 1 round, 1 match (pure final)', () {
      final rounds = TournamentBracketBuilder.buildRounds([_team('A'), _team('B')]);
      expect(rounds.length, 1);
      expect(rounds.first.length, 1);
      expect(rounds.first.first['home'], 'A');
      expect(rounds.first.first['away'], 'B');
    });

    test('4 teams → 2 rounds (SF + Final)', () {
      final teams = ['A', 'B', 'C', 'D'].map(_team).toList();
      final rounds = TournamentBracketBuilder.buildRounds(teams);
      // No opening round needed (4 == 2^2), so: R1 (2 matches) + Final (1 match)
      expect(rounds.length, 2);
      expect(rounds[0].length, 2); // semi-finals
      expect(rounds[1].length, 1); // final
    });

    test('8 teams → 3 rounds', () {
      final teams = List.generate(8, (i) => _team('T$i'));
      final rounds = TournamentBracketBuilder.buildRounds(teams);
      expect(rounds.length, 3);
      expect(rounds[0].length, 4);
      expect(rounds[1].length, 2);
      expect(rounds[2].length, 1);
    });

    test('5 teams → opening round + 2 main rounds', () {
      // 5 teams: next power of 2 is 8, so 3 opening matches... wait:
      // targetP2 = 4 (smallest power-of-2 >= 5/2), actually:
      // p=1 → 2 → 4; 4*2=8 > 5 → targetP2=4
      // numOpeningMatches = 5 - 4 = 1 opening match
      // So: R0 (1 match), R1 (2 matches), Final (1 match) = 3 rounds
      final teams = List.generate(5, (i) => _team('T$i'));
      final rounds = TournamentBracketBuilder.buildRounds(teams);
      expect(rounds.length, 3);
      expect(rounds[0].length, 1); // opening
      expect(rounds[1].length, 2); // QF
      expect(rounds[2].length, 1); // Final
    });

    test('6 teams → opening round + 2 main rounds', () {
      // targetP2=4, numOpeningMatches=2
      // R0: 2 matches, R1: 2 matches, Final: 1 match
      final teams = List.generate(6, (i) => _team('T$i'));
      final rounds = TournamentBracketBuilder.buildRounds(teams);
      expect(rounds.length, 3);
      expect(rounds[0].length, 2);
    });

    test('match maps always contain home and away keys', () {
      final teams = ['A', 'B', 'C', 'D', 'E'].map(_team).toList();
      final rounds = TournamentBracketBuilder.buildRounds(teams);
      for (final round in rounds) {
        for (final match in round) {
          expect(match.containsKey('home'), isTrue);
          expect(match.containsKey('away'), isTrue);
          expect(match['home'], isNotEmpty);
          expect(match['away'], isNotEmpty);
        }
      }
    });

    test('16 teams → 4 rounds (all powers of 2)', () {
      final teams = List.generate(16, (i) => _team('T$i'));
      final rounds = TournamentBracketBuilder.buildRounds(teams);
      expect(rounds.length, 4);
      expect(rounds[0].length, 8);
    });

    test('3 teams → opening + final (2 rounds)', () {
      // targetP2=2, numOpeningMatches=1, R0:1, R1:1 → 2 rounds
      final teams = ['A', 'B', 'C'].map(_team).toList();
      final rounds = TournamentBracketBuilder.buildRounds(teams);
      expect(rounds.length, 2);
      expect(rounds[0].length, 1); // opening
      expect(rounds[1].length, 1); // final
    });

    test('team names appear in first round matches', () {
      final teams = [_team('Arsenal'), _team('Barcelona')];
      final rounds = TournamentBracketBuilder.buildRounds(teams);
      final firstMatch = rounds.first.first;
      expect(firstMatch['home'], 'Arsenal');
      expect(firstMatch['away'], 'Barcelona');
    });
  });
}
