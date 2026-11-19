import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/team_profile/team_profile_stats_grid.dart';

void main() {
  test('member count is unknown until membership source succeeds', () {
    expect(TeamProfileStatsGrid.memberCountText(null), '—');
    expect(TeamProfileStatsGrid.memberCountText(-1), '—');
    expect(TeamProfileStatsGrid.memberCountText(0), '0');
    expect(TeamProfileStatsGrid.memberCountText(5), '5');
  });

  test('team profile no longer trusts the stale embedded member list', () {
    final source = File(
      'lib/features/player/screens/team_profile_screen.dart',
    ).readAsStringSync();
    final start = source.indexOf('int? get _teamMemberCount');
    final end = source.indexOf('Future<void> _generateMatchupInviteCode()', start);
    expect(start, isNonNegative);
    expect(end, greaterThan(start));
    final logic = source.substring(start, end);
    expect(logic, contains('if (_verifiedMemberIds == null) return null;'));
    expect(logic, isNot(contains('team.memberUids.where')));
    expect(logic, contains('team.captainId'));
  });

  test('member count unavailable is spoken clearly, not presented as zero', () {
    final source = File(
      'lib/features/player/widgets/team_profile/team_profile_stats_grid.dart',
    ).readAsStringSync();
    expect(source, contains("isArabic ? 'غير متاح' : 'Unavailable'"));
    expect(source, contains("spokenValue ?? value"));
    expect(source, isNot(contains('totalMembersCount.toString()')));
  });
  test('negative win draw and loss counters are not represented as results', () {
    expect(TeamProfileStatsGrid.recordCountText(-5), '—');
    expect(TeamProfileStatsGrid.recordCountText(-1), '—');
    expect(TeamProfileStatsGrid.recordCountText(0), '0');
    expect(TeamProfileStatsGrid.recordCountText(7), '7');
  });

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('invalid team counters have accessible unavailable labels: ${locale.languageCode}',
        (tester) async {
      final team = Team(
        id: 'team-invalid', name: 'Falcons',
        captainName: 'Captain', captainImageUrl: '', date: '',
        stadium: '', pricePerPerson: 0, currentPlayers: 5, maxPlayers: 5,
        wins: -2, draws: 2, losses: -3,
      );
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TeamProfileStatsGrid(
          team: team, totalMembersCount: -1,
        )),
      ));
      expect(find.text('-2'), findsNothing);
      expect(find.text('-3'), findsNothing);
      expect(find.text('—'), findsNWidgets(3));
      expect(find.text('2'), findsOneWidget);
      final unavailable = locale.languageCode == 'ar'
          ? 'غير متاح' : 'Unavailable';
      final winLabel = AppLocalizations.of(
          tester.element(find.byType(TeamProfileStatsGrid)))!.wins;
      expect(find.bySemanticsLabel('$winLabel: $unavailable'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Draws: $unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

}
