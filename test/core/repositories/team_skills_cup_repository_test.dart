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

  test('malformed registration, roster and identifiers fail before any RPC', () async {
    const players = ['1', '2', '3', '4', '5'];
    Future<void> invalidRegistration({
      String cupId = 'cup',
      String teamId = 'team',
      List<String> ids = players,
    }) async {
      await expectLater(repository.registerTeam(
        cupId: cupId, teamId: teamId, playerIds: ids,
        goalkeeperId: '1', representativeId: '2',
      ), throwsA(isA<StateError>()));
    }

    await invalidRegistration(cupId: '  ');
    await invalidRegistration(teamId: '');
    await invalidRegistration(ids: ['1', '2', '3', '4', ' ']);
    await invalidRegistration(ids: ['1', '2', '3', '4', ' 5']);

    await expectLater(repository.correctRoster(
      registrationId: 'pending', playerIds: const ['1', '2', '3', '4', ' '],
      goalkeeperId: '1', representativeId: '2',
    ), throwsA(isA<StateError>()));
    await expectLater(repository.correctRoster(
      registrationId: ' ', playerIds: players,
      goalkeeperId: '1', representativeId: '2',
    ), throwsA(isA<StateError>()));
    await expectLater(repository.getActiveRoster(' '),
        throwsA(isA<StateError>()));
    await expectLater(repository.withdrawRegistration(' '),
        throwsA(isA<StateError>()));
  });

  test('roster correction blocks stale saves and clears previous load errors', () {
    final source = File(
      'lib/features/player/widgets/champion/team_skills_roster_correction_screen.dart',
    ).readAsStringSync();
    expect(source, contains('bool _rosterVerified = false;'));
    expect(source, contains('_rosterVerified && _selectedPlayers.length == 5'));
    expect(source, contains('_loading = true;'));
    expect(source, contains('_rosterVerified = false;'));
    expect(source, contains('_rosterVerified = true;'));
    expect(source, contains('_error = null;'));
    expect(source, contains('if (mounted && session == _sessionGeneration)'));
    expect(source, contains('setState(() => _saving = false);'));
  });

  test('captain roster edit clears private selection on account switch', () {
    final source = File(
      'lib/features/player/widgets/champion/team_skills_roster_correction_screen.dart',
    ).readAsStringSync();
    expect(source, contains('void didChangeDependencies()'));
    expect(source, contains('context.watch<AuthProvider>().currentUser?.id'));
    expect(source, contains('actorId == _viewerUserId'));
    expect(source, contains('++_sessionGeneration;'));
    expect(source, contains('++_loadGeneration;'));
    expect(source, contains('_members = [];'));
    expect(source, contains('_selectedPlayers.clear();'));
    expect(source, contains('_rosterVerified = false;'));
    expect(source, contains('request != _loadGeneration'));
    expect(source, contains('session != _sessionGeneration'));
    expect(source, contains('WidgetsBinding.instance.addPostFrameCallback'));
  });

  test('captain roster edit validates live application and stored roles', () {
    final source = File(
      'lib/features/player/widgets/champion/team_skills_roster_correction_screen.dart',
    ).readAsStringSync();
    expect(source, contains('getRegistrations(widget.cupId)'));
    expect(source, contains('getCupById(widget.cupId)'));
    expect(source, contains('TeamSkillsCupRepository.canCorrectRoster('));
    expect(source, contains("row['team_id']?.toString() == widget.teamId"));
    expect(source, contains("row['captain_id']?.toString() == widget.captainId"));
    expect(source, contains('_serverGoalkeeperId = serverKeeper;'));
    expect(source, contains('_serverRepresentativeId = serverRepresentative;'));
    expect(source, contains('_goalkeeper != _serverGoalkeeperId'));
    expect(source, contains('_representative != _serverRepresentativeId'));
    expect(source, contains('!_rosterVerified || _saving'));
    expect(source, contains('لم يعد تعديل التشكيلة متاحًا لهذا الطلب'));
    expect(source, contains("row['cup_id']?.toString() != widget.cupId"));
    expect(source, contains("row['team_id']?.toString() != widget.teamId"));
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
    expect(repo, contains('hospitality_payment_status,checked_in_at,created_at,withdrawal_reason,withdrawn_at'));
    expect(tab, contains('_memberTeamIds'));
    expect(tab, contains('myRegistrations'));
    expect(tab, contains('statusText('));
    expect(tab, contains('if (myRegistrations.isNotEmpty)'));
    // Only the captain's branch can open the registration action form.
    expect(tab, contains('TeamSkillsCupRepository.registrationOpen(visibleCup) && _captainTeams.isNotEmpty'));
    expect(tab, contains('final freshCup = await widget.repository.getCupById(cupId);'));
    expect(tab, contains('TeamSkillsCupRepository.registrationOpen(freshCup)'));
    expect(tab, contains('_cupStateCurrent = false;'));
  });

  test('only the active captain may withdraw unpaid pending or waiting requests', () {
    bool may({
      String? cup = 'registration',
      String? status = 'pending',
      String? captain = 'captain',
      String? viewer = 'captain',
      String? hospitality = 'unpaid',
      bool checkedIn = false,
    }) => TeamSkillsCupRepository.canWithdrawRegistration(
      cupStatus: cup, status: status, captainId: captain,
      viewerId: viewer, hospitalityStatus: hospitality,
      hasCheckedIn: checkedIn,
    );
    expect(may(), isTrue);
    expect(may(status: 'waitlist'), isTrue);
    expect(may(status: 'approved'), isFalse);
    expect(may(status: 'withdrawn'), isFalse);
    expect(may(cup: 'live'), isFalse);
    expect(may(cup: 'cancelled'), isFalse);
    expect(may(viewer: 'other-user'), isFalse);
    expect(may(viewer: null), isFalse);
    expect(may(hospitality: 'verified'), isFalse);
    expect(may(hospitality: 'waived'), isFalse);
    expect(may(checkedIn: true), isFalse);
  });

  test('withdrawal requires an explicit confirmation and network recovery check', () {
    final tab = File('lib/features/player/widgets/champion/team_skills_cup_tab.dart')
        .readAsStringSync();
    final repo = File('lib/core/repositories/team_skills_cup_repository.dart')
        .readAsStringSync();
    expect(repo, contains("rpc('team_skills_withdraw_registration'"));
    expect(tab, contains('showDialog<bool>('));
    // Edit and withdrawal now share the same captain/unpaid/pending gate.
    expect(tab, contains('canCorrectRoster('));
    expect(tab, contains("value: 'withdraw'"));
    expect(tab, contains("action == 'withdraw'"));
    expect(tab, contains('await widget.repository.withdrawRegistration('));
    expect(repo, contains("row['status'] == 'withdrawn'"));
    expect(tab, contains('isCaptainWithdrawalConfirmed('));
    expect(tab, contains('تحقق من حالة طلبك قبل المحاولة مجددًا'));
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

  test('captain edit and withdrawal lock before opening routes or dialogs', () {
    final source = File(
      'lib/features/player/widgets/champion/team_skills_cup_tab.dart',
    ).readAsStringSync();
    final editStart = source.indexOf('Future<void> _editRegistration(');
    final withdrawStart = source.indexOf('Future<void> _withdrawRegistration(');
    final buildStart = source.indexOf('  Widget build(', withdrawStart);
    expect(buildStart, greaterThan(withdrawStart));
    final editor = source.substring(editStart, withdrawStart);
    final withdraw = source.substring(withdrawStart, buildStart);
    expect(editor.indexOf('setState(() => _submitting = true)'),
      lessThan(editor.indexOf('Navigator.of(context).push<bool>(')));
    expect(editor, contains('} finally {'));
    expect(editor, contains('setState(() => _submitting = false);'));
    expect(withdraw.indexOf('_submitting = true;'),
      lessThan(withdraw.indexOf('showDialog<bool>(')));
    expect(withdraw, contains('if (confirmed != true'));
    expect(withdraw, contains('} finally {'));
    expect(withdraw, contains('setState(() => _submitting = false);'));
  });

  test('roster edit preview is limited to current unpaid pending/waitlisted captain', () {
    bool allowed({
      String cup = 'registration', String status = 'pending',
      String viewer = 'captain', String captain = 'captain',
      String hospitality = 'unpaid', bool checkedIn = false,
    }) => TeamSkillsCupRepository.canCorrectRoster(
      cupStatus: cup, status: status,
      captainId: captain, viewerId: viewer,
      hospitalityStatus: hospitality, hasCheckedIn: checkedIn,
    );
    expect(allowed(), isTrue);
    expect(allowed(status: 'waitlist'), isTrue);
    expect(allowed(status: 'approved'), isFalse);
    expect(allowed(status: 'withdrawn'), isFalse);
    expect(allowed(status: 'rejected'), isFalse);
    expect(allowed(viewer: 'other-user'), isFalse);
    expect(allowed(cup: 'live'), isFalse);
    expect(allowed(hospitality: 'verified'), isFalse);
    expect(allowed(hospitality: 'waived'), isFalse);
    expect(allowed(checkedIn: true), isFalse);
  });

  test('roster correction refuses invalid player sets before any network request', () async {
    Future<void> invalid(List<String> players, String keeper, String representative) async {
      await expectLater(
        repository.correctRoster(
          registrationId: 'pending-registration',
          playerIds: players,
          goalkeeperId: keeper,
          representativeId: representative,
        ),
        throwsA(isA<StateError>()),
      );
    }
    await invalid(['1','2','3','4'], '1', '2');
    await invalid(['1','2','3','4','4'], '1', '2');
    await invalid(['1','2','3','4','5'], '6', '2');
    await invalid(['1','2','3','4','5'], '1', '6');
    await expectLater(
      repository.correctRoster(registrationId: '', playerIds: [
        '1','2','3','4','5',
      ], goalkeeperId: '1', representativeId: '2'),
      throwsA(isA<StateError>()),
    );
  });

  test('captain can edit five players before approval with verified server receipt', () {
    final tab=File('lib/features/player/widgets/champion/team_skills_cup_tab.dart')
        .readAsStringSync();
    final screen=File(
      'lib/features/player/widgets/champion/team_skills_roster_correction_screen.dart',
    ).readAsStringSync();
    final repo=File('lib/core/repositories/team_skills_cup_repository.dart')
        .readAsStringSync();
    expect(tab, contains('TeamSkillsRosterCorrectionScreen('));
    expect(tab, contains('canCorrectRoster('));
    expect(tab, contains("value: 'edit'"));
    expect(tab, contains("value: 'withdraw'"));
    expect(screen, contains('getActiveRoster(widget.registrationId)'));
    expect(screen, contains('getRosterOptions(widget.teamId)'));
    expect(screen, contains('correctRoster('));
    expect(screen, contains('_confirmedOnServer()'));
    expect(screen, contains('Navigator.of(context).pop(true)'));
    expect(screen, contains('context.watch<AuthProvider>().currentUser?.id'));
    expect(repo, contains("rpc('team_skills_correct_roster'"));
    expect(repo, contains(".eq('active', true)"));
    expect(screen, isNot(contains('service_role')));
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
    // The screen now verifies exactly one approved row rather than
    // arbitrarily trusting rows.first. An absent or conflicting row is unknown.
    // The player screen must cap each approved score by the actual published
    // stage weight, not by a fixed 25-point default.
    expect(tab, contains('TeamSkillsCupTab.verifiedWeightedStagePoints('));
    expect(tab, contains("rows, phase['weight']"));
    expect(tab, contains("values.single['computed_points']"));
    expect(tab, contains("if (values.length != 1) return '—';"));
    expect(tab, isNot(contains("rows.first['computed_points']")));
  });

  test('roster edit feedback reflects the latest admin review, not an assumed pending state', () {
    final tab = File(
      'lib/features/player/widgets/champion/team_skills_cup_tab.dart',
    ).readAsStringSync();
    expect(tab, contains('final latest = await widget.repository.getRegistrations(cupId);'));
    expect(tab, contains('_registrations = latest;'));
    expect(tab, contains('_loadFuture = _reload();'));
    expect(tab, contains("status == 'approved'"));
    expect(tab, contains("status == 'waitlist'"));
    expect(tab, contains("status == 'pending'"));
    expect(tab, contains('تم حفظ التشكيلة، وقد اعتمدت الإدارة مشاركة فريقك'));
    expect(tab, isNot(contains('تم حفظ التشكيلة المحدثة، وما زال الطلب ينتظر مراجعة الإدارة')));
  });

  test('edit confirmation is scoped to the same cup, team and captain', () {
    final tab = File(
      'lib/features/player/widgets/champion/team_skills_cup_tab.dart',
    ).readAsStringSync();
    final handlerStart = tab.indexOf('Future<void> _editRegistration(');
    final withdrawStart = tab.indexOf('Future<void> _withdrawRegistration(');
    final editHandler = tab.substring(handlerStart, withdrawStart);
    expect(editHandler, contains('final latest = await widget.repository.getRegistrations(cupId);'));
    expect(editHandler, contains("row['cup_id']?.toString() == cupId"));
    expect(editHandler, contains("row['team_id']?.toString() == registration['team_id']?.toString()"));
    expect(editHandler, contains("row['captain_id']?.toString() == viewerId"));
    expect(editHandler, isNot(contains('await _loadFuture;')));
  });

  test('captain sees the actual bounded waitlist status after registration', () {
    final tab = File('lib/features/player/widgets/champion/team_skills_cup_tab.dart')
        .readAsStringSync();
    expect(tab, contains("confirmed['status'] == 'waitlist'"));
    expect(tab, contains('confirmed == null'));
    expect(tab, contains('TeamSkillsCupRepository.findCaptainRegistration('));
    expect(tab, contains('تم تسجيل فريقك في قائمة الانتظار'));
    expect(tab, contains("case 'waitlist':"));
    expect(tab, contains('final receiptId = await widget.repository.registerTeam('));
    expect(tab, contains("candidate?['id']?.toString() == receiptId"));
  });


  test('captain registration and withdrawal receipt reads bypass leaderboard polling', () {
    final source = File(
      'lib/features/player/widgets/champion/team_skills_cup_tab.dart',
    ).readAsStringSync();
    final submitStart = source.indexOf('Future<void> _submit() async');
    final editStart = source.indexOf('Future<void> _editRegistration(');
    final withdrawStart = source.indexOf('Future<void> _withdrawRegistration(');
    final buildStart = source.indexOf('  Widget build(', withdrawStart);
    expect(buildStart, greaterThan(withdrawStart));
    final submitHandler = source.substring(submitStart, editStart);
    final withdrawHandler = source.substring(withdrawStart, buildStart);
    expect(submitHandler, contains('final receiptId = await widget.repository.registerTeam('));
    expect(submitHandler, contains('final latest = await widget.repository.getRegistrations(cupId);'));
    expect(submitHandler, contains("candidate?['id']?.toString() == receiptId"));
    expect(submitHandler, contains('_registrations = latest;'));
    expect(submitHandler, isNot(contains('await _reload();')));
    expect(withdrawHandler, contains('final latest = await widget.repository.getRegistrations(cupId);'));
    expect(withdrawHandler, contains('isCaptainWithdrawalConfirmed('));
    expect(withdrawHandler, contains('_registrations = latest;'));
    expect(withdrawHandler, isNot(contains('await _reload();')));
  });

  test('captain withdrawal is only confirmed by own terminal registration', () {
    final rows = <Map<String,dynamic>>[
      {'id':'request-1','captain_id':'captain','status':'pending'},
      {'id':'request-2','captain_id':'other','status':'withdrawn'},
      {'id':'request-3','captain_id':'captain','status':'withdrawn'},
    ];
    bool confirmed(String id,String actor) =>
        TeamSkillsCupRepository.isCaptainWithdrawalConfirmed(
          rows,registrationId:id,captainId:actor);
    expect(confirmed('request-3','captain'),isTrue);
    expect(confirmed('request-1','captain'),isFalse);
    expect(confirmed('request-2','captain'),isFalse);
    expect(confirmed('request-3','other'),isFalse);
    expect(confirmed('','captain'),isFalse);
  });

  test('captain success toasts require a persisted registration or withdrawal', () {
    final source = File(
      'lib/features/player/widgets/champion/team_skills_cup_tab.dart',
    ).readAsStringSync();
    expect(source,contains('confirmed == null'));
    expect(source,contains('isCaptainWithdrawalConfirmed('));
    expect(source,contains('تم إرسال طلب السحب لكن تعذر تأكيد حالته'));
    expect(source,contains('تم إرسال الطلب لكن تعذر تأكيد تسجيل الفريق'));
    expect(source,contains('تم سحب طلب الفريق وتحرير مكانه'));
  });

  test('Team Skills notification deep-link validates source and cup UUID', () {
    const cupId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
    expect(TeamSkillsCupRepository.cupIdFromNotificationMetadata(
      {'source':'team_skills_cup','cup_id':cupId}), cupId);
    for (final metadata in <Map<String,dynamic>?>[
      null,
      {},
      {'source':'booking','cup_id':cupId},
      {'source':'team_skills_cup','cup_id':'../../../admin'},
      {'source':'team_skills_cup','cup_id':'not-a-uuid'},
      {'source':'team_skills_cup','cup_id':''},
    ]) {
      expect(TeamSkillsCupRepository.cupIdFromNotificationMetadata(metadata),
        isNull, reason: '$metadata');
    }
  });

  test('cup notifications recheck current account and fetch under published-cup RLS', () {
    final repository = File('lib/core/repositories/team_skills_cup_repository.dart')
        .readAsStringSync();
    final center = File('lib/features/player/screens/notifications_center_screen.dart')
        .readAsStringSync();
    expect(repository, contains('getCupById(String cupId)'));
    expect(repository, contains("['registration', 'live', 'completed']"));
    expect(repository, contains('.maybeSingle()'));
    expect(center, contains('cupIdFromNotificationMetadata(metadata)'));
    expect(center, contains('await repository.getCupById(cupId)'));
    expect(center, contains("currentUser?.id != userId"));
    expect(center, contains('TeamSkillsCupDetailsScreen('));
    expect(center, contains('if (cup != null)'));
  });

  test('lost registration reply is reconciled only from same captain and team', () {
    final rows = <Map<String, dynamic>>[
      {'team_id':'team-1','captain_id':'other','status':'approved'},
      {'team_id':'team-2','captain_id':'captain-1','status':'pending'},
      {'team_id':'team-1','captain_id':'captain-1','status':'waitlist'},
    ];
    final result = TeamSkillsCupRepository.findCaptainRegistration(
      rows, teamId:'team-1', captainId:'captain-1',
    );
    expect(result?['status'], 'waitlist');
    expect(TeamSkillsCupRepository.findCaptainRegistration(
      rows, teamId:'team-1', captainId:'attacker',
    ), isNull);
    expect(TeamSkillsCupRepository.findCaptainRegistration(
      rows, teamId:'other-team', captainId:'captain-1',
    ), isNull);
    expect(TeamSkillsCupRepository.findCaptainRegistration(
      [{'team_id':'team-1','captain_id':'captain-1','status':'rejected'}],
      teamId:'team-1', captainId:'captain-1',
    ), isNull);
  });

  test('captain registration retries query server before showing a failure', () {
    final tab = File('lib/features/player/widgets/champion/team_skills_cup_tab.dart')
        .readAsStringSync();
    expect(tab, contains('await widget.repository.getRegistrations(cupId)'));
    expect(tab, contains('TeamSkillsCupRepository.findCaptainRegistration('));
    expect(tab, contains('viewerId != _viewerUserId'));
    expect(tab, contains('طلب فريقك مسجل بالفعل على قائمة الانتظار'));
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
