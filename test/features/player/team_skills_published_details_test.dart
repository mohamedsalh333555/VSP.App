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
    }, isArabic: true), ['اسم عربي', 'جائزة 2', 'Announcement']);
    expect(TeamSkillsPublishedDetails.publishedPrizeLabels({
      'prizes': {'not': 'an array'},
    }, isArabic: true), isEmpty);
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

  test('Team Skills stage label uses published count, not twelve by default', () {
    expect(TeamSkillsCupTab.publishedStageSummary(
      const [], isArabic: false), 'Competition stages have not been announced yet');
    expect(TeamSkillsCupTab.publishedStageSummary(
      const [{'stage_no': 1}, {'stage_no': 2}, {'stage_no': 3}],
      isArabic: false), '3 announced stages');
  });

  test('a live cup never shows unannounced winners, even if award rows exist', () {
    const winner = {
      'team_id': 'team-a', 'award_type': 'team_champion',
      'announced_at': '2026-11-18T10:00:00Z',
    };
    const pending = {
      'team_id': 'team-a', 'award_type': 'best_goalkeeper',
      'player_id': null, 'announced_at': '2026-11-18T10:00:00Z',
    };
    expect(TeamSkillsCupTab.visiblePublishedAwards(
      cup: {'id': 'cup-1', 'name': 'Cup', 'status': 'live'},
      awards: [winner]), isEmpty);
    final visible = TeamSkillsCupTab.visiblePublishedAwards(
      cup: {'id': 'cup-1', 'name': 'Cup', 'status': 'completed'},
      awards: [winner, winner, pending]);
    expect(visible.length, 1);
    expect(visible.first['award_type'], 'team_champion');
  });

}
