import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/champion/team_skills_published_details.dart';

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
            'ميداليات',
          ],
        },
      ))),
    ));
    expect(find.textContaining('Aswan'), findsOneWidget);
    expect(find.textContaining('ملعب النيل'), findsOneWidget);
    expect(find.textContaining('البداية:'), findsOneWidget);
    expect(find.textContaining('النهاية:'), findsOneWidget);
    expect(find.textContaining('75 جنيه'), findsOneWidget);
    expect(find.textContaining('8'), findsOneWidget);
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
}
