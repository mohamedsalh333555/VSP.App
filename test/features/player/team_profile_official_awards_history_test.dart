import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/team_skills_cup_repository.dart';
import 'package:vsp_application/core/repositories/matchup_repository.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/champion/team_skills_history_section.dart';
import 'package:vsp_application/features/player/widgets/team_profile/team_profile_head_to_head_section.dart';
import 'package:vsp_application/features/player/widgets/team_profile/team_profile_hero_header.dart';

class _HistorySpy implements TeamSkillsCupRepository {
  int requests = 0;
  @override
  Future<List<Map<String, dynamic>>> getTeamHistory(String teamId) async {
    requests++;
    return [
      {'award_type': 'team_champion', 'cup_name': 'Verified cup'},
    ];
  }
  @override
  Future<List<Map<String, dynamic>>> getPlayerHistory(String playerId) async {
    requests++;
    return [];
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Team _team() => Team(
  id: 'team-a',
  name: 'Falcons',
  captainName: 'Captain',
  captainImageUrl: '',
  date: '',
  stadium: '',
  pricePerPerson: 0,
  currentPlayers: 5,
  maxPlayers: 5,
);

Widget _wrap(Widget child, Locale locale) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('Team Skills rollout must require verified project and participant ID', () {
    expect(TeamSkillsHistorySection.shouldLoad(enabled: false, participantId: 'team'), isFalse);
    expect(TeamSkillsHistorySection.shouldLoad(enabled: true, participantId: '  '), isFalse);
    expect(TeamSkillsHistorySection.shouldLoad(enabled: true, participantId: 'team'), isTrue);
  });

  test('Team Skills knockout final is not advertised as the retired 1v1 tournament', () {
    expect(TeamSkillsHistorySection.awardTitle('one_v_one_champion', isArabic: true), 'بطل نهائي المهارات');
    expect(TeamSkillsHistorySection.awardTitle('one_v_one_champion', isArabic: false), 'Skills final champion');
    expect(TeamSkillsHistorySection.awardTitle('team_champion', isArabic: false), 'Team Skills champion');
    expect(TeamSkillsHistorySection.awardTitle('best_goalkeeper', isArabic: true), 'أفضل حارس');
  });

  testWidgets('disabled Team Skills history performs no private RPC', (tester) async {
    final spy = _HistorySpy();
    await tester.pumpWidget(_wrap(TeamSkillsHistorySection(
      participantId: 'team-a',
      isTeam: true,
      repository: spy,
    ), const Locale('en')));
    await tester.pumpAndSettle();
    expect(spy.requests, 0);
    expect(find.text('Verified cup'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('corrupt or missing head-to-head counters do not become fabricated draws', () {
    expect(TeamProfileHeadToHeadSection.validCount(null), isNull);
    expect(TeamProfileHeadToHeadSection.validCount('3'), isNull);
    expect(TeamProfileHeadToHeadSection.validCount(-1), isNull);
    expect(TeamProfileHeadToHeadSection.validCount(3), 3);
  });

  test('announced awards exclude invalid recipients and duplicates', () {
    final rows = <Map<String, dynamic>>[
      {'cup_id': 'cup-a', 'cup_name': 'Cup A', 'team_id': 'team-a',
       'award_type': 'team_champion', 'announced_at': '2026-11-17T18:00:00Z'},
      {'cup_id': 'cup-a', 'cup_name': 'Cup A', 'team_id': 'team-a',
       'award_type': 'team_champion', 'announced_at': '2026-11-17T18:00:00Z'},
      {'cup_id': 'cup-b', 'cup_name': 'Cup B', 'team_id': 'team-b',
       'award_type': 'best_goalkeeper', 'announced_at': '2026-11-18T18:00:00Z',
       'player_id': 'keeper-b'},
      {'cup_id': 'cup-c', 'cup_name': 'Cup C', 'team_id': 'team-a',
       'award_type': 'team_champion', 'announced_at': null},
      {'cup_id': 'cup-d', 'cup_name': 'Cup D', 'team_id': 'team-a',
       'award_type': 'team_champion', 'announced_at': 'not-a-date'},
      {'cup_id': '', 'cup_name': 'Cup E', 'team_id': 'team-a',
       'award_type': 'team_champion', 'announced_at': '2026-11-17T18:00:00Z'},
      {'cup_id': 'cup-e', 'cup_name': 'Cup E', 'team_id': 'team-a',
       'award_type': 'unverified_award', 'announced_at': '2026-11-17T18:00:00Z'},
      {'cup_id': 'cup-f', 'cup_name': '', 'team_id': 'team-a',
       'award_type': 'team_champion', 'announced_at': '2026-11-17T18:00:00Z'},
      {'cup_id': 'cup-g', 'cup_name': 'Cup G', 'team_id': 'team-a',
       'award_type': 'best_goalkeeper', 'announced_at': '2026-11-17T18:00:00Z'},
    ];
    final awards = TeamSkillsHistorySection.visibleAwards(rows);
    expect(awards.map((row) => row['cup_id']), ['cup-a', 'cup-b']);
  });

  test('team and player history cannot show another team or player award', () {
    final rows = <Map<String, dynamic>>[
      {'cup_id': 'cup-a', 'cup_name': 'Cup A', 'team_id': 'team-a',
       'award_type': 'team_champion', 'announced_at': '2026-11-16T15:00:00Z'},
      {'cup_id': 'cup-b', 'cup_name': 'Cup B', 'team_id': 'team-b',
       'player_id': 'player-b', 'award_type': 'best_goalkeeper',
       'announced_at': '2026-11-17T15:00:00Z'},
      {'cup_id': 'cup-c', 'cup_name': 'Cup C', 'team_id': 'team-a',
       'player_id': 'player-a', 'award_type': 'one_v_one_champion',
       'announced_at': '2026-11-18T15:00:00Z'},
    ];
    expect(TeamSkillsHistorySection.visibleAwards(rows,
      participantId: 'team-a', isTeam: true).map((row) => row['cup_id']),
      ['cup-a', 'cup-c']);
    expect(TeamSkillsHistorySection.visibleAwards(rows,
      participantId: 'player-b', isTeam: false).map((row) => row['cup_id']),
      ['cup-b']);
    expect(TeamSkillsHistorySection.visibleAwards(rows,
      participantId: 'other-team', isTeam: true), isEmpty);
    expect(TeamSkillsHistorySection.visibleAwards(rows,
      participantId: '', isTeam: true), isEmpty);
  });

  test('a team history query cannot interpolate malformed PostgREST identifiers', () {
    expect(MatchupRepository.isCanonicalTeamId(
      '08c5fc4b-189d-4f41-b1e0-5798d1f9a804'), isTrue);
    expect(MatchupRepository.isCanonicalTeamId('team-a'), isFalse);
    expect(MatchupRepository.isCanonicalTeamId(''), isFalse);
    expect(MatchupRepository.isCanonicalTeamId(
      '08c5fc4b-189d-4f41-b1e0-5798d1f9a804,team_b_id.neq.null'), isFalse);
    expect(MatchupRepository.isCanonicalTeamId(
      '08c5fc4b-189d-4f41-b1e0-5798d1f9a804)or(true'), isFalse);
  });

  test('strict team matchup query rejects cross-team or corrupt server rows', () {
    const a = '82e73247-e111-4ab9-abd5-04cf6fe6779a';
    const b = '741f2b99-5097-4a38-98b0-7d818e266a12';
    const c = 'dd13cc05-c234-4902-a3e8-bd9e215c99d7';
    const valid = <String, dynamic>{
      'team_a_id': a, 'team_b_id': b, 'team_a_wins': 2,
    };
    expect(MatchupRepository.everyHeadToHeadRowBelongsToTeam(a, []), isTrue);
    expect(MatchupRepository.everyHeadToHeadRowBelongsToTeam(a, [valid]), isTrue);
    expect(MatchupRepository.everyHeadToHeadRowBelongsToTeam(a, [
      valid, {'team_a_id': b, 'team_b_id': a},
    ]), isTrue);
    for (final suspicious in <Map<String, dynamic>>[
      {'team_a_id': b, 'team_b_id': c},
      {'team_a_id': a, 'team_b_id': a},
      {'team_a_id': a, 'team_b_id': 'other'},
      {'team_a_id': a, 'team_b_id': null},
    ]) {
      expect(MatchupRepository.everyHeadToHeadRowBelongsToTeam(
        a, [valid, suspicious]), isFalse);
    }
    expect(MatchupRepository.everyHeadToHeadRowBelongsToTeam(
      'not-a-uuid', [valid]), isFalse);
  });

  test('team matchup read only joins public names, never private team data', () {
    const a = '82e73247-e111-4ab9-abd5-04cf6fe6779a';
    const b = '741f2b99-5097-4a38-98b0-7d818e266a12';
    const c = 'dd13cc05-c234-4902-a3e8-bd9e215c99d7';
    final visible = MatchupRepository.withPublicTeamNames(a, [
      {'team_a_id': a, 'team_b_id': b, 'team_a_wins': 2,
       'team_b_wins': 0, 'draws': 1, 'secret': 'DO_NOT_LEAK'},
      {'team_a_id': b, 'team_b_id': c, 'team_a_wins': 42,
       'team_b_wins': 0, 'draws': 0},
      {'team_a_id': a, 'team_b_id': a, 'team_a_wins': 99},
      {'team_a_id': a, 'team_b_id': 'malformed', 'team_a_wins': 99},
    ], [
      {'id': a, 'name': 'Team A', 'logo_url': '/a.png',
       'invite_code': 'DO_NOT_LEAK'},
      {'id': b, 'name': 'Team B', 'logo_url': '/b.png',
       'captain_phone': 'DO_NOT_LEAK'},
    ]);
    expect(visible, hasLength(1));
    expect(visible.single['team_a_wins'], 2);
    expect((visible.single['team_b'] as Map)['name'], 'Team B');
    expect(visible.single.containsKey('secret'), isFalse);
    expect((visible.single['team_b'] as Map).containsKey('captain_phone'),
        isFalse);
    expect(MatchupRepository.withPublicTeamNames('not-a-uuid', [], []), isEmpty);
  });

  test('team match progress is deduplicated and never invents a rank', () {
    final history = <Map<String, dynamic>>[
      {'team_a_id': 'team-a', 'team_b_id': 'team-b',
       'team_a_wins': 3, 'team_b_wins': 1, 'draws': 2},
      {'team_a_id': 'team-b', 'team_b_id': 'team-a',
       'team_a_wins': 1, 'team_b_wins': 3, 'draws': 2},
      {'team_a_id': 'team-a', 'team_b_id': 'team-c',
       'team_a_wins': -1, 'team_b_wins': 0, 'draws': 1},
      {'team_a_id': 'team-a', 'team_b_id': 'team-d',
       'team_a_wins': 0, 'team_b_wins': 0, 'draws': 0},
      {'team_a_id': 'team-x', 'team_b_id': 'team-y',
       'team_a_wins': 50, 'team_b_wins': 0, 'draws': 0},
    ];
    final totals = TeamProfileHeadToHeadSection.recordedTotals('team-a', history);
    expect(totals, isNotNull);
    expect(totals!.wins, 3);
    expect(totals.draws, 2);
    expect(totals.losses, 1);
    expect(totals.opponents, 1);
    expect(TeamProfileHeadToHeadSection.recordedTotals(
      'outsider', history), isNull);
  });

  test('head-to-head rows must involve exactly the displayed team', () {
    final rows = <Map<String, dynamic>>[
      {'team_a_id': 'team-a', 'team_b_id': 'team-b', 'team_a_wins': 1},
      {'team_a_id': 'team-c', 'team_b_id': 'team-a', 'team_b_wins': 2},
      {'team_a_id': 'team-x', 'team_b_id': 'team-y', 'team_a_wins': 40},
      {'team_a_id': 'team-a', 'team_b_id': 'team-a', 'team_a_wins': 99},
      {'team_a_id': 'team-a', 'team_b_id': null},
      {'team_a_id': 'team-a', 'team_b_id': '  '},
    ];
    final visible = TeamProfileHeadToHeadSection.recordsForTeam('team-a', rows);
    expect(visible.length, 2);
    expect(visible[0]['team_b_id'], 'team-b');
    expect(visible[1]['team_a_id'], 'team-c');
    expect(TeamProfileHeadToHeadSection.recordsForTeam(' ', rows), isEmpty);
  });

  test('mirrored and identical repeated opponent rows appear once', () {
    const original = <String, dynamic>{
      'team_a_id': 'team-a', 'team_b_id': 'team-b',
      'team_a_wins': 3, 'team_b_wins': 1, 'draws': 2,
    };
    const mirrored = <String, dynamic>{
      'team_a_id': 'team-b', 'team_b_id': 'team-a',
      'team_a_wins': 1, 'team_b_wins': 3, 'draws': 2,
    };
    final visible = TeamProfileHeadToHeadSection.recordsForTeam(
      'team-a', [original, mirrored, original]);
    expect(visible, hasLength(1));
    final totals = TeamProfileHeadToHeadSection.recordedTotals(
      'team-a', [original, mirrored, original]);
    expect(totals?.wins, 3);
    expect(totals?.draws, 2);
    expect(totals?.losses, 1);
  });

  test('contradictory opponent aggregates fail closed, even after repeats', () {
    const baseline = <String, dynamic>{
      'team_a_id': 'team-a', 'team_b_id': 'team-b',
      'team_a_wins': 3, 'team_b_wins': 1, 'draws': 2,
    };
    const contradiction = <String, dynamic>{
      'team_a_id': 'team-b', 'team_b_id': 'team-a',
      'team_a_wins': 2, 'team_b_wins': 3, 'draws': 2,
    };
    const trustworthy = <String, dynamic>{
      'team_a_id': 'team-a', 'team_b_id': 'team-c',
      'team_a_wins': 1, 'team_b_wins': 0, 'draws': 0,
    };
    final visible = TeamProfileHeadToHeadSection.recordsForTeam(
      'team-a', [baseline, contradiction, baseline, trustworthy]);
    expect(visible, hasLength(1));
    expect(visible.single['team_b_id'], 'team-c');
    final totals = TeamProfileHeadToHeadSection.recordedTotals(
      'team-a', [baseline, contradiction, baseline, trustworthy]);
    expect(totals?.wins, 1);
    expect(totals?.opponents, 1);
    expect(TeamProfileHeadToHeadSection.recordedTotals(
      'team-a', [baseline, contradiction]), isNull);
  });

  testWidgets('contradictory matchup is not presented as a result',
      (tester) async {
    await tester.pumpWidget(_wrap(TeamProfileHeadToHeadSection(
      team: _team(),
      headToHeadRecords: const [
        {'team_a_id': 'team-a', 'team_b_id': 'team-b',
         'team_a_wins': 3, 'team_b_wins': 1, 'draws': 1},
        {'team_a_id': 'team-a', 'team_b_id': 'team-b',
         'team_a_wins': 2, 'team_b_wins': 1, 'draws': 1},
      ],
    ), const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('3 wins'), findsNothing);
    expect(find.text('Head-to-head totals only, not a ranking change'),
        findsNothing);
    expect(find.text('Available head-to-head records cannot be verified'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('localized team matchup totals render independently of current score: ${locale.languageCode}',
        (tester) async {
      await tester.pumpWidget(_wrap(TeamProfileHeadToHeadSection(
        team: _team(),
        headToHeadRecords: const [
          {
            'team_a_id': 'team-a',
            'team_b_id': 'team-b',
            'team_b': {'name': 'Wolves', 'logo_url': ''},
            'team_a_wins': 3,
            'team_b_wins': 1,
            'draws': 2,
          },
          {
            'team_a_id': 'team-c',
            'team_b_id': 'team-a',
            'team_a': {'name': 'Lions', 'logo_url': ''},
            'team_a_wins': 2,
            'team_b_wins': 0,
            'draws': null,
          },
        ],
      ), locale));
      await tester.pumpAndSettle();
      final ar = locale.languageCode == 'ar';
      expect(find.text(ar ? 'ضد Wolves' : 'vs Wolves'), findsOneWidget);
      expect(find.text(ar ? 'فوز: 3 | تعادل: 2 | خسارة: 1'
                           : 'Wins: 3 | Draws: 2 | Losses: 1'), findsOneWidget);
      expect(find.text(ar ? 'بيانات المواجهات غير مكتملة'
                          : 'Head-to-head counts unavailable'), findsOneWidget);
      expect(find.text(ar
          ? 'المواجهات المسجلة: 3 فوز • 2 تعادل • 1 خسارة'
          : 'Recorded matchups: 3 W • 2 D • 1 L'), findsOneWidget);
      expect(find.text(ar
          ? 'إجمالي المواجهات المباشرة فقط، وليس تغييرًا في الترتيب'
          : 'Head-to-head totals only, not a ranking change'), findsOneWidget);
      expect(find.text('3 - 1'), findsNothing);
      expect(find.text(ar ? '3 فوز' : '3 wins'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('an empty verified read is a friendly empty state: ${locale.languageCode}',
        (tester) async {
      await tester.pumpWidget(_wrap(TeamProfileHeadToHeadSection(
        team: _team(), headToHeadRecords: const [],
      ), locale));
      await tester.pumpAndSettle();
      final ar = locale.languageCode == 'ar';
      expect(find.text(ar
          ? 'لا توجد مواجهات مسجلة حتى الآن'
          : 'No recorded matchups yet'), findsOneWidget);
      expect(find.text(ar
          ? 'بيانات المواجهات المتاحة غير صالحة للعرض'
          : 'Available head-to-head records cannot be verified'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('legacy 1v1 label is explicitly historical, not a current cup', (tester) async {
    await tester.pumpWidget(_wrap(TeamProfileHeroHeader(
      team: _team(), has1v1Champion: true,
    ), const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('Historical 1v1 champion'), findsOneWidget);
    expect(find.text('Includes a 1v1 champion'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('unplayed opponent aggregate is not displayed as a real win: ${locale.languageCode}',
        (tester) async {
      await tester.pumpWidget(_wrap(TeamProfileHeadToHeadSection(
        team: _team(),
        headToHeadRecords: const [{
          'team_a_id': 'team-a', 'team_b_id': 'team-b',
          'team_b': {'name': 'Wolves', 'logo_url': ''},
          'team_a_wins': 0, 'team_b_wins': 0, 'draws': 0,
        }],
      ), locale));
      await tester.pumpAndSettle();
      final ar = locale.languageCode == 'ar';
      expect(find.text(ar ? 'ضد Wolves' : 'vs Wolves'), findsOneWidget);
      expect(find.text(ar ? 'لم تُلعب مواجهات مسجلة مع هذا الفريق'
                          : 'No recorded games played against this team'), findsOneWidget);
      expect(find.text(ar ? '0 فوز' : '0 wins'), findsNothing);
      expect(find.text(ar
          ? 'المواجهات المسجلة: 0 فوز • 0 تعادل • 0 خسارة'
          : 'Recorded matchups: 0 W • 0 D • 0 L'), findsNothing);
      expect(find.text('—'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('official cup rejects every contradictory award recipient, never picking first', () {
    const stamp = '2026-11-18T12:00:00Z';
    final rows = <Map<String, dynamic>>[
      {'cup_id': 'cup-conflict', 'cup_name': 'Cup', 'team_id': 'team-a',
       'award_type': 'team_champion', 'announced_at': stamp},
      {'cup_id': 'cup-conflict', 'cup_name': 'Cup', 'team_id': 'team-b',
       'award_type': 'team_champion', 'announced_at': stamp},
      {'cup_id': 'cup-conflict', 'cup_name': 'Cup', 'team_id': 'team-a',
       'award_type': 'team_champion', 'announced_at': stamp},
      {'cup_id': 'cup-valid', 'cup_name': 'Other Cup', 'team_id': 'team-a',
       'award_type': 'team_champion', 'announced_at': stamp},
    ];
    expect(TeamSkillsHistorySection.visibleAwards(rows)
        .map((row) => row['cup_id']), ['cup-valid']);
    expect(TeamSkillsHistorySection.visibleAwards(rows,
        participantId: 'team-a', isTeam: true)
        .map((row) => row['cup_id']), ['cup-valid']);
  });

  test('same cup cannot crown two individual finalists with different player IDs', () {
    const stamp = '2026-11-18T12:00:00Z';
    final rows = <Map<String, dynamic>>[
      {'cup_id': 'cup-1', 'cup_name': 'Cup', 'team_id': 'team-a',
       'player_id': 'first', 'award_type': 'one_v_one_champion',
       'announced_at': stamp},
      {'cup_id': 'cup-1', 'cup_name': 'Cup', 'team_id': 'team-a',
       'player_id': 'second', 'award_type': 'one_v_one_champion',
       'announced_at': stamp},
    ];
    expect(TeamSkillsHistorySection.visibleAwards(rows), isEmpty);
  });

  test('team champion cannot be assigned an arbitrary individual recipient', () {
    final rows = <Map<String, dynamic>>[
      {'cup_id': 'cup-a', 'cup_name': 'Cup', 'team_id': 'team-a',
       'player_id': 'unverified', 'award_type': 'team_champion',
       'announced_at': '2026-11-18T12:00:00Z'},
      {'cup_id': 'cup-b', 'cup_name': 'Cup', 'team_id': 'team-a',
       'award_type': 'team_champion',
       'announced_at': '2026-11-18T12:00:00Z'},
    ];
    expect(TeamSkillsHistorySection.visibleAwards(rows).map((e) => e['cup_id']),
        ['cup-b']);
  });

  test('a team trophy is never tied to a malformed non-null individual recipient', () {
    const stamp = '2026-11-18T16:00:00Z';
    final rows = <Map<String, dynamic>>[
      for (final bad in ['', 0, false, <String, dynamic>{}])
        {'cup_id': 'bad-${bad.runtimeType}', 'cup_name': 'Invalid',
         'team_id': 'team-a', 'player_id': bad,
         'award_type': 'team_champion', 'announced_at': stamp},
      {'cup_id': 'valid', 'cup_name': 'Valid', 'team_id': 'team-a',
       'player_id': null, 'award_type': 'team_champion',
       'announced_at': stamp},
    ];
    expect(TeamSkillsHistorySection.visibleAwards(rows).map((a) => a['cup_id']),
        ['valid']);
  });

}
