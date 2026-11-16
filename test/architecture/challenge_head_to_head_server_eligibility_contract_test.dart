import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/team/team_payload_builder.dart';

void main() {
  test('only eligible confirmed and scored challenges enter history', () {
    final raw = <Map<String, dynamic>>[
      {
        'booking_type': 'challenge', 'player_team_id': 'team-a',
        'opponent_team_id': 'team-b', 'match_result_status': 'confirmed',
        'elo_processed': true, 'final_outcome': 'homeWin',
      },
      {
        'booking_type': 'challenge', 'player_team_id': 'team-a',
        'opponent_team_id': 'team-b', 'match_result_status': 'noResult',
        'elo_processed': true, 'final_outcome': 'draw',
      },
      {
        'booking_type': 'challenge', 'player_team_id': 'team-a',
        'opponent_team_id': 'team-b', 'match_result_status': 'confirmed',
        'elo_processed': false, 'final_outcome': 'awayWin',
      },
      {
        'booking_type': 'matchup', 'player_team_id': 'team-a',
        'opponent_team_id': 'team-b', 'match_result_status': 'confirmed',
        'elo_processed': true, 'final_outcome': 'draw',
      },
      {
        'booking_type': 'challenge', 'player_team_id': 'stranger-1',
        'opponent_team_id': 'stranger-2', 'match_result_status': 'confirmed',
        'elo_processed': true, 'final_outcome': 'draw',
      },
      {
        'booking_type': 'challenge', 'player_team_id': 'team-a',
        'opponent_team_id': 'team-b', 'match_result_status': 'confirmed',
        'elo_processed': true, 'final_outcome': 'homeWin',
        'is_result_excluded': true,
      },
      {
        'booking_type': 'challenge', 'player_team_id': 'team-b',
        'opponent_team_id': 'team-a', 'match_result_status': 'confirmed',
        'elo_processed': true, 'final_outcome': 'homeWin',
      },
      {
        'booking_type': 'challenge', 'player_team_id': 'team-a',
        'opponent_team_id': 'team-b', 'match_result_status': 'confirmed',
        'elo_processed': true, 'final_outcome': 'draw',
      },
    ];
    expect(
      TeamPayloadBuilder.calculateHeadToHead(raw,'team-a','team-b'),
      {'teamAWins': 1, 'teamBWins': 1,
       'draws': 1, 'totalMatches': 3},
    );
  });

  test('rollout never falls back to unfiltered client booking history',
      () {
    final source = File(
      'lib/core/repositories/team_repository.dart',
    ).readAsStringSync();
    final signature = source.indexOf('getHeadToHeadStats(');
    final method = source.substring(
      signature, source.indexOf('@Deprecated(', signature),
    );
    expect(method, contains(
      'ChallengeResultRolloutFlags.nonPlayedReportsEnabled',
    ));
    expect(method, contains(
      'return getEligibleChallengeHeadToHeadStats(team1Id, team2Id);',
    ));
    expect(method, contains(".eq('booking_type', 'challenge')"));
    expect(method, contains(".eq('match_result_status', 'confirmed')"));
    expect(method, contains(".eq('elo_processed', true)"));
    expect(method, contains(
      ".inFilter('final_outcome', ['homeWin', 'awayWin', 'draw'])",
    ));
    expect(method, contains('uuid.hasMatch(team1Id)'));
    expect(method, contains('uuid.hasMatch(team2Id)'));
  });
}
