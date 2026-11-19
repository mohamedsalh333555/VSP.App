import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/matchup_repository.dart';
import 'package:vsp_application/data/models.dart';

MatchupTeam _team(String teamId) => MatchupTeam(
  id: 'fixture-$teamId', bookingId: 'fixture-matchup',
  teamId: teamId, teamName: 'Synthetic $teamId',
  addedByUserId: 'fixture-owner', joinedAt: DateTime(2026, 11, 1),
);

MatchupResult _result(String id, String home, String away, String outcome) =>
    MatchupResult(
      id: id, bookingId: 'fixture-matchup',
      teamAId: home, teamBId: away, outcome: outcome,
      recordedBy: 'fixture-captain', createdAt: DateTime(2026, 11, 1),
    );

void main() {
  final repo = MatchupRepository();

  test('malformed and pending matchup rows cannot award a synthetic draw',
      () {
    final records = [
      _result('bad-null', 'a', 'b', ''),
      _result('bad-pending', 'a', 'b', 'pending'),
      _result('bad-legacy', 'a', 'b', 'homeWin'),
      _result('same-team', 'a', 'a', 'draw'),
      _result('other-team', 'a', 'not-on-roster', 'draw'),
    ];
    final standings = repo.calculateStandings([_team('a'), _team('b')],
        records);
    expect(standings, hasLength(2));
    for (final row in standings) {
      expect(row.matchesPlayed, 0);
      expect(row.points, 0);
      expect(row.wins, 0);
      expect(row.draws, 0);
      expect(row.losses, 0);
    }
  });

  test('valid matchup results count exactly 3/1/0 without disturbing opponents',
      () {
    final standings = repo.calculateStandings(
      [_team('a'), _team('b'), _team('c')],
      [
        _result('first', 'a', 'b', 'team_a_win'),
        _result('second', 'b', 'a', 'team_a_win'),
        _result('third', 'a', 'b', 'draw'),
        _result('fourth', 'a', 'b', 'team_b_win'),
        _result('invalid', 'a', 'b', 'undecided'),
      ],
    );
    final a = standings.singleWhere((v) => v.teamId == 'a');
    final b = standings.singleWhere((v) => v.teamId == 'b');
    final c = standings.singleWhere((v) => v.teamId == 'c');
    expect((a.matchesPlayed,a.wins,a.draws,a.losses,a.points), (4,1,1,2,4));
    expect((b.matchesPlayed,b.wins,b.draws,b.losses,b.points), (4,2,1,1,7));
    expect((c.matchesPlayed,c.wins,c.draws,c.losses,c.points), (0,0,0,0,0));
    expect(standings.first.teamId, 'b');
  });

  test('incomplete fromMap match cannot become a draw', () {
    final row = MatchupResult.fromMap({
      'id': 'fixture', 'booking_id': 'match', 'team_a_id': 'a',
      'team_b_id': 'b', 'recorded_by': 'test',
    });
    expect(row.outcome, isEmpty);
    final standings = repo.calculateStandings([_team('a'), _team('b')],
        [row]);
    expect(standings.every((v) => v.points == 0 &&
        v.matchesPlayed == 0), isTrue);
    expect(MatchupResult.fromMap({
      'id': 'draw', 'team_a_id': 'a', 'team_b_id': 'b',
      'outcome': 'draw',
    }).outcome, 'draw');
  });
}
