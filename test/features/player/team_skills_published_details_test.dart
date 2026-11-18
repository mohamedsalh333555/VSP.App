import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/champion/team_skills_published_details.dart';
import 'package:vsp_application/features/player/widgets/champion/team_skills_cup_tab.dart';


void main() {
  testWidgets('published cup shows venue, scheduled times, fee, cap and prizes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: TeamSkillsPublishedDetails(
        isArabic: true,
        stadiumName: 'ملعب النيل',
        cup: {
          'governorate': 'Aswan',
          'stadium_id': 'venue-1',
          'starts_at': '2026-11-22T16:00:00Z',
          'ends_at': '2026-11-22T18:30:00Z',
          'max_teams': 8,
          'hospitality_fee': 75,
          'prizes': [
            {'title_ar': 'كأس الفريق البطل'},
            {'place': 2, 'award': 'ميداليات'},
          ],
        },
      ))),
    ));
    expect(find.textContaining('Aswan'), findsOneWidget);
    expect(find.textContaining('ملعب النيل'), findsOneWidget);
    expect(find.textContaining('البداية:'), findsOneWidget);
    expect(find.textContaining('النهاية:'), findsOneWidget);
    expect(find.textContaining('75 جنيه'), findsOneWidget);
    expect(find.text('عدد الفرق الأقصى: 8'), findsOneWidget);
    expect(find.textContaining('كأس الفريق البطل'), findsOneWidget);
    expect(find.textContaining('ميداليات'), findsOneWidget);
    expect(find.textContaining('توقيت جهازك'), findsOneWidget);
  });

  testWidgets('missing published data does not claim fictitious venue or prizes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TeamSkillsPublishedDetails(
        isArabic: false,
        stadiumName: null,
        cup: {'prizes': <Object>[], 'hospitality_fee': 0},
      )),
    ));
    expect(find.textContaining('Venue name unavailable'), findsOneWidget);
    expect(find.textContaining('Not specified'), findsWidgets);
    expect(find.textContaining('No prizes have been announced'), findsOneWidget);
    expect(find.textContaining('0 EGP'), findsOneWidget);
  });

  test('prizes are not raw JSON and prefer localized verified labels', () {
    expect(TeamSkillsPublishedDetails.publishedPrizeLabels({
      'prizes': [
        {'name': 'English name', 'name_ar': 'اسم عربي'},
        {'unrecognized': 'secret'},
        {'title': 'Announcement'},
      ],
    }, isArabic: true), ['اسم عربي', 'Announcement']);
    expect(TeamSkillsPublishedDetails.publishedPrizeLabels({
      'prizes': {'not': 'an array'},
    }, isArabic: true), isEmpty);
  });
  test('published fee and capacity are validated without inventing a price', () {
    expect(TeamSkillsPublishedDetails.publishedFee({'hospitality_fee': 0}), '0');
    expect(TeamSkillsPublishedDetails.publishedFee({'hospitality_fee': '75.25'}), '75.25');
    expect(TeamSkillsPublishedDetails.publishedFee({'hospitality_fee': -1}), '—');
    expect(TeamSkillsPublishedDetails.publishedFee({'hospitality_fee': double.nan}), '—');
    expect(TeamSkillsPublishedDetails.publishedFee({'hospitality_fee': 'not money'}), '—');
    expect(TeamSkillsPublishedDetails.publishedCapacity({'max_teams': 8}), '8');
    expect(TeamSkillsPublishedDetails.publishedCapacity({'max_teams': '8'}), '—');
    expect(TeamSkillsPublishedDetails.publishedCapacity({'max_teams': -8}), '—');
  });

  testWidgets('unknown prize objects and invalid fee never become public claims', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: TeamSkillsPublishedDetails(
        isArabic: false, stadiumName: null, cup: {
          'max_teams': -8, 'hospitality_fee': -50,
          'prizes': [
            {'unrecognized': 'not-a-prize'},
            {'title': 'Official cup'},
            {'title': 'Official cup'},
          ],
        },
      )),
    )));
    expect(find.text('Maximum teams: —'), findsOneWidget);
    expect(find.text('Team hospitality: Not announced'), findsOneWidget);
    expect(find.text('• Official cup'), findsOneWidget);
    expect(find.textContaining('Prize 1'), findsNothing);
    expect(find.textContaining('not-a-prize'), findsNothing);
    expect(find.textContaining('-50 EGP'), findsNothing);
  });

  test('cup discovery never invents points, team capacity or a completed state', () {
    expect(TeamSkillsCupTab.publishedMetadata(<String, dynamic>{},
        isArabic: false), '');
    expect(TeamSkillsCupTab.publishedMetadata(
        {'governorate': null, 'max_teams': null}, isArabic: true), '');
    expect(TeamSkillsCupTab.publishedMetadata(
        {'governorate': 'Aswan', 'max_teams': 8}, isArabic: false),
        'Aswan • 8 teams');
    expect(TeamSkillsCupTab.publishedMetadata(
        {'governorate': 'Aswan', 'max_teams': -1}, isArabic: true),
        'Aswan');
    expect(TeamSkillsCupTab.statusLabel(null, isArabic: false),
        'Tournament status unavailable');
    expect(TeamSkillsCupTab.statusLabel('registration', isArabic: true),
        'التسجيل مفتوح');
  });

  test('a completed cup does not advertise new registration', () {
    expect(TeamSkillsCupTab.actionLabel('completed', isArabic: false),
        'Results and announced awards');
    expect(TeamSkillsCupTab.actionLabel('live', isArabic: false),
        'Tournament details and standings');
    expect(TeamSkillsCupTab.actionLabel('registration', isArabic: false),
        'Details and registration');
  });

  test('verified stage zero is distinct from unknown or conflicting results', () {
    expect(TeamSkillsCupTab.verifiedStagePoints(const []), '—');
    expect(TeamSkillsCupTab.verifiedStagePoints(const [
      {'computed_points': null}
    ]), '—');
    expect(TeamSkillsCupTab.verifiedStagePoints(const [
      {'computed_points': 0}
    ]), '0');
    expect(TeamSkillsCupTab.verifiedStagePoints(const [
      {'computed_points': 25}
    ]), '25');
    expect(TeamSkillsCupTab.verifiedStagePoints(const [
      {'computed_points': 0}, {'computed_points': 25}
    ]), '—');
    for (final invalid in [-1, 26, double.nan, double.infinity, '0']) {
      expect(TeamSkillsCupTab.verifiedStagePoints([
        {'computed_points': invalid}
      ]), '—');
    }
  });

  test('Team Skills stage label uses published count, not twelve by default', () {
    expect(TeamSkillsCupTab.publishedStageSummary(
      const [], isArabic: false), 'Competition stages have not been announced yet');
    expect(TeamSkillsCupTab.publishedStageSummary(
      const [{'stage_no': 1}, {'stage_no': 2}, {'stage_no': 3}],
      isArabic: false), '3 announced stages');
    expect(TeamSkillsCupTab.publishedStageSummary(const [
      {'stage_no': 1}, {'stage_no': 1}, {'stage_no': 2},
      {'stage_no': -1}, {'stage_no': null},
    ], isArabic: false), '2 announced stages');
    final phases = <Map<String, dynamic>>[
      {'stage_no': 3, 'name_ar': 'A', 'weight': 10},
      {'stage_no': 1, 'name_ar': 'First', 'weight': 5},
      {'stage_no': 1, 'name_ar': 'Different', 'weight': 9},
      {'stage_no': 2, 'name_ar': 'Second', 'weight': 7},
      {'stage_no': 3, 'name_ar': 'A', 'weight': 10},
      {'stage_no': -1, 'name_ar': 'Invalid', 'weight': 12},
    ];
    final visible = TeamSkillsCupTab.visiblePublishedPhases(phases);
    expect(visible.map((p) => p['stage_no']), [2, 3]);
    expect(TeamSkillsCupTab.publishedStageSummary(
      phases, isArabic: false), '2 announced stages');
    expect(TeamSkillsCupTab.publishedStageSummary(
      phases, isArabic: true), '2 مرحلة معلنة');
    expect(TeamSkillsCupTab.visiblePublishedPhases([
      {'stage_no': 8, 'name_ar': 'Same'},
      {'stage_no': 8, 'name_ar': 'Same'},
    ]), hasLength(1));
  });

  test('a live cup never shows unannounced winners, even if award rows exist', () {
    const winner = {
      'cup_id': 'cup-1', 'team_id': 'team-a', 'award_type': 'team_champion',
      'announced_at': '2026-11-18T10:00:00Z',
    };
    const pending = {
      'cup_id': 'cup-1', 'team_id': 'team-a', 'award_type': 'best_goalkeeper',
      'player_id': null, 'announced_at': '2026-11-18T10:00:00Z',
    };
    expect(TeamSkillsCupTab.visiblePublishedAwards(
      cup: {'id': 'cup-1', 'name': 'Cup', 'status': 'live'},
      awards: [winner]), isEmpty);
    final visible = TeamSkillsCupTab.visiblePublishedAwards(
      cup: {'id': 'cup-1', 'name': 'Cup', 'status': 'completed'},
      awards: [winner, winner, pending,
        {...winner, 'cup_id': 'another-cup'},
        {...winner, 'cup_id': null}]);
    expect(visible.length, 1);
    expect(visible.first['award_type'], 'team_champion');
  });

  test('published cup discovery filters fake IDs, unpublished states and other governorates', () {
    const cupId = '82e73247-e111-4ab9-abd5-04cf6fe6779a';
    const otherId = '741f2b99-5097-4a38-98b0-7d818e266a12';
    final rows = <Map<String, dynamic>>[
      {'id': cupId, 'name': 'Aswan Skills', 'status': 'registration',
       'governorate': 'Aswan'},
      {'id': cupId, 'name': 'Aswan Skills', 'status': 'registration',
       'governorate': 'Aswan'},
      {'id': otherId, 'name': 'Alex Cup', 'status': 'completed',
       'governorate': 'Alexandria'},
      {'id': 'not-a-uuid', 'name': 'Fake Cup', 'status': 'registration'},
      {'id': 'dd13cc05-c234-4902-a3e8-bd9e215c99d7',
       'name': '', 'status': 'live'},
      {'id': '6d201c45-6099-46e3-a6f4-d60ebcb7c70d',
       'name': 'Draft cup', 'status': 'draft'},
    ];
    expect(TeamSkillsCupTab.visiblePublishedCups(rows).length, 2);
    expect(TeamSkillsCupTab.visiblePublishedCups(rows,
        selectedLocation: 'Aswan').map((cup) => cup['name']),
        ['Aswan Skills']);
    expect(TeamSkillsCupTab.visiblePublishedCups(rows,
        selectedLocation: 'Cairo'), isEmpty);
  });

  test('conflicting copies of same published cup ID never choose first row', () {
    const id = '82e73247-e111-4ab9-abd5-04cf6fe6779a';
    final rows = <Map<String, dynamic>>[
      {'id': id, 'name': 'First', 'status': 'registration'},
      {'id': id, 'name': 'First', 'status': 'completed'},
      {'id': id, 'name': 'First', 'status': 'registration'},
    ];
    expect(TeamSkillsCupTab.visiblePublishedCups(rows), isEmpty);
  });

}
