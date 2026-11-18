import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final home = File(
    'lib/features/player/screens/player_home_screen.dart',
  ).readAsStringSync();
  final feed = File(
    'lib/features/player/widgets/home/home_feed_content.dart',
  ).readAsStringSync();
  final topBar = File(
    'lib/features/player/widgets/home/home_top_bar.dart',
  ).readAsStringSync();

  test('86.01: home retains discovery, sponsor, stadium, match and cup order', () {
    // A source-level guard: it intentionally does not modify the Home UI.
    // Widget/RTL and real-device acceptance remain separate release gates.
    const sections = [
      'HomeTopBar(onNavigate: onNavigate)',
      "BannerSliderWidget(placement: 'home_slider')",
      'HomeStadiumsSection()',
      'HomeMatchesSection(onNavigate: onNavigate)',
      'HomeChampionshipsSection(onNavigate: onNavigate)',
    ];
    var lastIndex = -1;
    for (final section in sections) {
      final index = feed.indexOf(section);
      expect(index, greaterThan(lastIndex), reason: 'Home section moved: $section');
      expect(feed.indexOf(section, index + section.length), -1,
          reason: 'Home section duplicated: $section');
      lastIndex = index;
    }
    expect(feed, contains('RefreshIndicator('));
    expect(topBar, contains('GlobalSearchScreen()'));
    expect(topBar, contains('FilterBottomSheet('));
    expect(topBar, contains('AppLocalizations.of(context)!'));
    expect(topBar, contains("languageCode == 'ar'"));
  });

  test('86.01: private achievements and repeat-booking stay off Home', () {
    const privateCards = [
      'TeamProfileAchievementsSection(',
      'TeamAchievementsSection(',
      'TeamSkillsHistorySection(',
      'TeamsRankingTab(',
      'RepeatBookingAction(',
    ];
    for (final forbidden in privateCards) {
      expect(feed, isNot(contains(forbidden)),
          reason: 'This content belongs in Team, Competitions or Bookings');
    }
    expect(home, contains('child: IndexedStack('));
    expect(home, contains('const BookingsScreen()'));
    expect(home, contains('const TeamDashboardScreen()'));
    expect(home, contains('ChampionScreen(key: championScreenKey)'));
  });

  test('86.01: five player navigation icons preserve outline/filled states', () {
    const iconPairs = [
      ['home_1_copy', 'home_1'],
      ['people_copy', 'people'],
      ['cup_copy', 'cup'],
      ['calendar_1_copy', 'calendar_1'],
      ['user_copy', 'user'],
    ];
    expect(RegExp(r'VspNavItem\(').allMatches(home).length, 5);
    for (final pair in iconPairs) {
      expect(home, contains('inactiveIcon: Iconsax.${pair[0]},'));
      expect(home, contains('activeIcon: Iconsax.${pair[1]},'));
    }
    expect(home, contains('AppLocalizations.of(context)!.homeNav'));
    expect(home, contains('AppLocalizations.of(context)!.matchesNav'));
    expect(home, contains('AppLocalizations.of(context)!.championNav'));
    expect(home, contains('AppLocalizations.of(context)!.bookedNav'));
    expect(home, contains('AppLocalizations.of(context)!.profileNav'));
  });
}
