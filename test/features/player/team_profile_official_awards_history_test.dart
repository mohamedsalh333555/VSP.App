import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/team_skills_cup_repository.dart';
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
            'team_a_id': 'team-b',
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
      expect(find.text('3 - 1'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
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
}
