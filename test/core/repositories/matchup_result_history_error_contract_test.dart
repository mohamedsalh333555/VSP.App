import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/matchup_repository.dart';

/// Substitutes only the strict data transport. No user, Supabase account,
/// backend SQL or production data is required to test fail-closed semantics.
class _InjectedHistoryRepository extends MatchupRepository {
  final Future<List<Map<String, dynamic>>> Function(String) _load;
  _InjectedHistoryRepository(this._load);

  @override
  Future<List<Map<String, dynamic>>> getAllHeadToHeadForTeamStrict(
          String teamId) =>
      _load(teamId);
}

void main() {
  test('strict head-to-head propagates outage instead of returning empty', () async {
    final repo = _InjectedHistoryRepository((id) async {
      expect(id, 'team-a');
      throw StateError('private-account-token:not-for-logs');
    });
    await expectLater(
      repo.getAllHeadToHeadForTeamStrict('team-a'),
      throwsA(isA<StateError>()),
    );
    expect(await repo.getAllHeadToHeadForTeam('team-a'), isEmpty);
  });

  test('strict and legacy reads preserve legitimate empty and nonempty data',
      () async {
    final rows = <Map<String, dynamic>>[
      {'team_a_id': 'team-a', 'team_b_id': 'team-b',
       'team_a_wins': 1, 'team_b_wins': 2, 'draws': 1},
    ];
    final repo = _InjectedHistoryRepository((id) async => rows);
    expect(await repo.getAllHeadToHeadForTeamStrict('team-a'), same(rows));
    expect(await repo.getAllHeadToHeadForTeam('team-a'), same(rows));
    final empty = _InjectedHistoryRepository((id) async => []);
    expect(await empty.getAllHeadToHeadForTeamStrict('team-a'), isEmpty);
  });

  test('team-profile live history uses strict read and redacts private errors',
      () {
    final profile = File(
      'lib/features/player/screens/team_profile_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/core/repositories/matchup_repository.dart',
    ).readAsStringSync();

    expect(profile, contains(
      'MatchupRepository().getAllHeadToHeadForTeamStrict(teamId)',
    ));
    expect(profile, contains('_hasHeadToHeadLoadError = true'));
    expect(repository, contains('getAllHeadToHeadForTeamStrict('));
    expect(repository, contains("from('team_head_to_head')"));

    for (final source in [profile, repository]) {
      final logLines = source.split('\n').where(
        (line) => line.contains('debugPrint('),
      );
      for (final line in logLines) {
        expect(RegExp(r'\$(?:e|error|userId|teamId|bookingId|uid)\b')
            .hasMatch(line), isFalse, reason: line);
        expect(line, isNot(contains('private-account-token')));
      }
    }
  });
}
