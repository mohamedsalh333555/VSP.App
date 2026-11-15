import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/team/team_payload_builder.dart';

void main() {
  const a = 'homeTeam';
  const b = 'awayTeam';

  test('all normalized challenge outcomes respect booking home/away roles', () {
    final result = TeamPayloadBuilder.calculateHeadToHead([
      {'player_team_id': a, 'opponent_team_id': b, 'final_outcome': 'homeWin'},
      {'player_team_id': a, 'opponent_team_id': b, 'final_outcome': 'awayWin'},
      {'player_team_id': b, 'opponent_team_id': a, 'final_outcome': 'homeWin'},
      {'player_team_id': b, 'opponent_team_id': a, 'final_outcome': 'awayWin'},
      {'player_team_id': a, 'opponent_team_id': b, 'final_outcome': 'draw'},
    ], a, b);
    expect(result, {
      'teamAWins': 2, 'teamBWins': 2, 'draws': 1, 'totalMatches': 5,
    });
  });

  test('legacy matchup representations remain compatible without double count', () {
    final result = TeamPayloadBuilder.calculateHeadToHead([
      {'player_team_id': a, 'final_outcome': 'team_a_win', 'winner_team_id': a},
      {'player_team_id': a, 'final_outcome': 'team_b_win', 'winner_team_id': b},
      {'player_team_id': b, 'final_outcome': 'team_a_win', 'winner_team_id': b},
      {'player_team_id': b, 'final_outcome': 'team_b_win', 'winner_team_id': a},
      {'player_team_id': a, 'final_outcome': 'tie'},
      {'player_team_id': '', 'winner_team_id': a, 'final_outcome': null},
      {'player_team_id': a, 'winner_team_id': b, 'final_outcome': 'homeWin'},
    ], a, b);
    expect(result, {
      'teamAWins': 4, 'teamBWins': 2, 'draws': 1, 'totalMatches': 7,
    });
  });

  test('exclude reported or mismatched results before considering old win badges', () {
    final result = TeamPayloadBuilder.calculateHeadToHead([
      {
        'player_team_id': a, 'final_outcome': 'homeWin',
        'winner_team_id': a, 'is_result_excluded': true,
      },
      {
        'player_team_id': a, 'final_outcome': 'homeWin',
        'non_played_status': 'excluded',
      },
      {
        'player_team_id': a, 'final_outcome': 'homeWin',
        'match_result_status': 'disputed',
      },
      {
        'player_team_id': b, 'final_outcome': 'awayWin',
        'match_result_status': 'waitingOpponent',
      },
      {'player_team_id': a, 'final_outcome': 'unknown', 'winner_team_id': null},
      {'player_team_id': b, 'final_outcome': 'awayWin'},
    ], a, b);
    expect(result, {
      'teamAWins': 1, 'teamBWins': 0, 'draws': 0, 'totalMatches': 1,
    });
  });
}
