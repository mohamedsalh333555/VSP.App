import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/my_team/team_achievement_badges.dart';
import 'package:vsp_application/features/player/widgets/my_team/team_achievement_summary.dart';

void main() {
  testWidgets('shows Arabic team achievements and zero states', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: [Locale('ar'), Locale('en')],
      home: Scaffold(
        body: TeamAchievementBadges(
          summary: TeamAchievementSummary(
            stadiumChampionships: 0,
            oneVsOneChampionPlayers: 0,
          ),
        ),
      ),
    ));
    expect(find.bySemanticsLabel('0 بطولات ملاعب رسمية، 0 أبطال واحد ضد واحد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows verified totals in English and fits small width', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      home: Scaffold(
        body: TeamAchievementBadges(
          summary: TeamAchievementSummary(
            stadiumChampionships: 3,
            oneVsOneChampionPlayers: 2,
          ),
        ),
      ),
    ));
    expect(find.bySemanticsLabel('3 verified stadium championships, 2 one versus one champion players'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
