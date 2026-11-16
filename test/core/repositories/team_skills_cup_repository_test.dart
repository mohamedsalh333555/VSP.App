import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/repositories/team_skills_cup_repository.dart';

void main() {
  final client = SupabaseClient('https://localhost.invalid', 'test-public-key');
  final repository = TeamSkillsCupRepository(client: client);

  test('team skills registration refuses wrong-sized and duplicated rosters locally', () async {
    Future<void> expectInvalid(List<String> ids, String keeper, String representative) async {
      await expectLater(
        repository.registerTeam(
          cupId: 'cup', teamId: 'team', playerIds: ids,
          goalkeeperId: keeper, representativeId: representative,
        ),
        throwsA(isA<StateError>()),
      );
    }

    await expectInvalid(['1','2','3','4'], '1', '2');
    await expectInvalid(['1','2','3','4','4'], '1', '2');
    await expectInvalid(['1','2','3','4','5'], '6', '2');
    await expectInvalid(['1','2','3','4','5'], '1', '6');
  });

  test('champion home has three tabs and replaces the old public 1v1 entry', () {
    final source=File('lib/features/player/screens/champion_screen.dart').readAsStringSync();
    expect(source, contains('TabController(length: 3'));
    expect(source, contains('TeamSkillsCupTab('));
    expect(source, contains("'مهارات الفرق'"));
    expect(source, isNot(contains('Vsp1v1LeagueTab(')));
    expect(source, isNot(contains('getActive1v1TournamentStream(')));
  });

  test('registration status is visible to members, without captain mutation access', () {
    final tab = File('lib/features/player/widgets/champion/team_skills_cup_tab.dart')
        .readAsStringSync();
    final repo = File('lib/core/repositories/team_skills_cup_repository.dart')
        .readAsStringSync();
    expect(repo, contains('getMemberTeamIds('));
    expect(repo, contains("from('team_members')"));
    expect(repo, contains("'hospitality_payment_status,checked_in_at,created_at'"));
    expect(tab, contains('_memberTeamIds'));
    expect(tab, contains('myRegistrations'));
    expect(tab, contains('statusText('));
    expect(tab, contains('if (myRegistrations.isNotEmpty)'));
    // Only the captain's branch can open the registration action form.
    expect(tab, contains("widget.cup['status'] == 'registration' && _captainTeams.isNotEmpty"));
  });

  test('team registration and points use a single guarded Supabase backend', () {
    final source=File('lib/core/repositories/team_skills_cup_repository.dart').readAsStringSync();
    expect(source, contains("rpc('team_skills_register'"));
    expect(source, contains("from('team_skills_leaderboard')"));
    expect(source, contains("from('team_skills_awards')"));
    expect(source, isNot(contains("from('team_skills_scores').insert")));
    expect(source, isNot(contains('service_role')));
  });
}
