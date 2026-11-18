import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/team_profile/team_profile_achievements_section.dart';
import 'package:vsp_application/features/player/widgets/my_team/team_achievements_section.dart';
import 'package:vsp_application/features/player/widgets/my_team/team_achievement_badges.dart';
import 'package:vsp_application/features/player/widgets/my_team/team_achievement_summary.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

Team _team() => Team(
  id: 'team-a', name: 'Falcons', captainName: 'Captain',
  captainImageUrl: '', date: '', stadium: '', pricePerPerson: 0,
  currentPlayers: 5, maxPlayers: 5, currentWinningStreak: 3,
  unlockedBadges: const ['explorer', 'streak_3'],
);

Widget _app(Widget child, Locale locale) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('team profile keeps activity separate from verified titles: '
        '${locale.languageCode}', (tester) async {
      final ar = locale.languageCode == 'ar';
      await tester.pumpWidget(_app(TeamProfileAchievementsSection(team: _team()), locale));
      await tester.pumpAndSettle();
      expect(find.text(ar
          ? 'شارات نشاط الفريق — ليست ألقاب بطولات رسمية'
          : 'Team activity badges — not official tournament titles'), findsOneWidget);
      expect(find.byType(TeamAchievementBadges), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('team management explains activity badges: '
        '${locale.languageCode}', (tester) async {
      final ar = locale.languageCode == 'ar';
      await tester.pumpWidget(_app(
        TeamAchievementsSection(team: _team(), isArabic: ar), locale,
      ));
      await tester.pumpAndSettle();
      expect(find.text(ar
          ? 'شارات نشاط الفريق — ليست ألقاب بطولات رسمية'
          : 'Team activity badges — not official tournament titles'), findsOneWidget);
      expect(find.byType(TeamAchievementBadges), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('official trophy counter is gated on verified results', (tester) async {
    await tester.pumpWidget(_app(TeamProfileAchievementsSection(
      team: _team(),
      verifiedSummary: const TeamAchievementSummary(
        stadiumChampionships: 1, oneVsOneChampionPlayers: 0),
    ), const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.byType(TeamAchievementBadges), findsOneWidget);
    expect(find.text('Stadium titles'), findsOneWidget);
  });
}
