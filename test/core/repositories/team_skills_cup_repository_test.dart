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

  test('session switch clears private cup membership and ignores stale responses', () {
    final source = File(
      'lib/features/player/widgets/champion/team_skills_cup_tab.dart',
    ).readAsStringSync();
    expect(source, contains('void didChangeDependencies()'));
    expect(source, contains('context.watch<AuthProvider>().currentUser?.id'));
    expect(source, contains('_viewerUserId != actorId'));
    expect(source, contains('_memberTeamIds = <String>{};'));
    expect(source, contains('_captainTeams = [];'));
    expect(source, contains('_registrations = [];'));
    expect(source, contains('_selectedPlayers.clear();'));
    expect(source, contains('generation != _readGeneration || viewerId != _viewerUserId'));
    expect(source, contains('if (!mounted || viewerId != _viewerUserId) return;'));
  });

  test('captain is selectable even if absent from team_members roster', () {
    final selected = TeamSkillsCupRepository.normalizeRosterWithCaptain(
      members: [
        {'uid':'member-1','name':'لاعب 1','phone':'01000000000'},
        {'uid':'member-2','name':'لاعب 2','phone':'01100000000'},
      ],
      currentUserId: 'captain-id',
      captainUserId: 'captain-id',
      captainName: 'الكابتن',
    );
    expect(selected.map((p) => p['uid']).toList(),
      ['member-1','member-2','captain-id']);
    expect(selected.last['name'], 'الكابتن');
    expect(selected.every((p) => !p.containsKey('phone')), isTrue,
      reason: 'Team Skills roster must not retain private phone numbers');
  });

  test('does not add a different user as team captain or duplicate actual captain', () {
    final options = TeamSkillsCupRepository.normalizeRosterWithCaptain(
      members: [{'uid':'member-1','name':'لاعب'}],
      currentUserId: 'not-captain',
      captainUserId: 'captain-id',
    );
    expect(options.length, 1);
    final captainIsMember = TeamSkillsCupRepository.normalizeRosterWithCaptain(
      members: [
        {'uid':'captain-id','name':'قائد مسجل'},
        {'uid':'captain-id','name':'عضو مكرر'},
      ],
      currentUserId: 'captain-id',
      captainUserId: 'captain-id',
    );
    expect(captainIsMember.length, 1);
    expect(captainIsMember.single['name'], 'قائد مسجل');
  });

  test('players can view approved per-stage points, never pending judge measurements', () {
    final repo = File('lib/core/repositories/team_skills_cup_repository.dart')
        .readAsStringSync();
    final tab = File('lib/features/player/widgets/champion/team_skills_cup_tab.dart')
        .readAsStringSync();
    expect(repo, contains('getApprovedScores('));
    expect(repo, contains("from('team_skills_scores')"));
    expect(repo, contains(".eq('status', 'approved')"));
    expect(repo, contains("'registration_id,stage_no,computed_points'"));
    expect(repo, contains("'cup_id,team_id,registration_id,points,completed_stages,all_stages_approved'"));
    expect(tab, contains('ExpansionTile('));
    expect(tab, contains('_approvedScores'));
    expect(tab, contains("rows.first['computed_points']"));
  });

  test('captain sees the actual bounded waitlist status after registration', () {
    final tab = File('lib/features/player/widgets/champion/team_skills_cup_tab.dart')
        .readAsStringSync();
    expect(tab, contains("registration['status'] == 'waitlist'"));
    expect(tab, contains('تم تسجيل فريقك في قائمة الانتظار'));
    expect(tab, contains("case 'waitlist':"));
    expect(tab, contains('await _reload();'));
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
