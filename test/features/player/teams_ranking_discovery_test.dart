import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/champion/teams_ranking_tab.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class _AnonymousAuth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isOwner => false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) return null;
    return super.noSuchMethod(invocation);
  }
}

Team _team(String id, String name, String governorate, String sport, {int points = 0}) => Team(
      id: id,
      name: name,
      captainName: 'Captain',
      captainImageUrl: '',
      date: 'Upcoming',
      stadium: 'Pitch',
      pricePerPerson: 0,
      currentPlayers: 5,
      maxPlayers: 10,
      governorate: governorate,
      sportType: sport,
      points: points,
      matchesPlayed: points > 0 ? 1 : 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('discovery lists only matching governorate and sport, then searches',
      (tester) async {
    final stream = Stream<List<Team>>.value([
      _team('aswan', 'Nile Stars', 'Aswan', 'Football'),
      _team('cairo', 'Cairo Hoops', 'Cairo', 'Basketball'),
    ]);
    Widget host(String location, String sport) => ChangeNotifierProvider<AuthProvider>(
          create: (_) => _AnonymousAuth(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TeamsRankingTab(
                teamsStream: stream,
                selectedLocation: location,
                selectedSport: sport,
                onRetry: () {},
              ),
            ),
          ),
        );

    await tester.pumpWidget(host('Aswan', 'Football'));
    await tester.pumpAndSettle();
    expect(find.text('Nile Stars'), findsOneWidget);
    expect(find.text('Cairo Hoops'), findsNothing);

    final search = find.byType(TextField);
    await tester.enterText(search, 'absent');
    await tester.pumpAndSettle();
    expect(find.text('Nile Stars'), findsNothing);

    await tester.enterText(search, 'Nile');
    await tester.pumpAndSettle();
    expect(find.text('Nile Stars'), findsOneWidget);

    await tester.pumpWidget(host('Cairo', 'Football'));
    await tester.pumpAndSettle();
    expect(find.text('Nile Stars'), findsNothing);
    expect(find.text('Cairo Hoops'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranking card opens the selected team profile', (tester) async {
    final team = _team('aswan-team', 'Nile Stars', 'Aswan', 'Football');
    String? openedTeamId;
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>(
      create: (_) => _AnonymousAuth(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TeamsRankingTab(
            teamsStream: Stream.value([team]),
            selectedLocation: 'Aswan',
            selectedSport: 'Football',
            onRetry: () {},
            teamProfileBuilder: (selected) {
              openedTeamId = selected.id;
              return Scaffold(body: Text('Team profile: ${selected.id}'));
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nile Stars'));
    await tester.pumpAndSettle();
    expect(openedTeamId, 'aswan-team');
    expect(find.text('Team profile: aswan-team'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('tied points get identical ranks and no unverified podium', () {
    final tied = [
      _team('a','A','Aswan','Football',points:12),
      _team('b','B','Aswan','Football',points:12),
      _team('c','C','Aswan','Football',points:10),
      _team('d','D','Aswan','Football',points:8),
    ];
    expect([for (var i = 0; i < tied.length; i++)
      TeamsRankingTab.rankAt(tied, i)], [1,1,3,4]);
    expect(TeamsRankingTab.podiumIsAmbiguous(tied), isTrue);
    expect(TeamsRankingTab.rankAt(tied,-1),0);
    expect(TeamsRankingTab.rankAt(tied,99),0);
    expect(TeamsRankingTab.podiumIsAmbiguous([
      _team('a','A','Aswan','Football',points:12),
      _team('b','B','Aswan','Football',points:11),
      _team('c','C','Aswan','Football',points:10),
      _team('d','D','Aswan','Football',points:10),
    ]),isTrue);
  });

  test('37.04: ties keep a shared rank while list order stays deterministic', () {
    final teams = [
      _team('z','Team Z','Aswan','Football',points:12),
      _team('b','Team B','Aswan','Football',points:11),
      _team('a','Team A','Aswan','Football',points:12),
      _team('d','Team D','Aswan','Football',points:10),
      _team('c','Team C','Aswan','Football',points:11),
    ];
    TeamsRankingTab.sortForDisplay(teams);
    expect([for (final team in teams) team.id], ['a','z','b','c','d']);
    expect([for (var i = 0; i < teams.length; i++)
      TeamsRankingTab.rankAt(teams, i)], [1,1,3,3,5]);
    expect(TeamsRankingTab.podiumIsAmbiguous(teams), isTrue);
  });

  test('37.04: changing ID cannot break a valid points tie', () {
    final teams = [
      _team('z-last','Higher alphabet','Aswan','Football',points:6),
      _team('a-first','Lower alphabet','Aswan','Football',points:6),
      _team('third','Third','Aswan','Football',points:3),
    ];
    TeamsRankingTab.sortForDisplay(teams);
    expect(teams.first.id, 'a-first');
    expect(TeamsRankingTab.rankAt(teams,0),1);
    expect(TeamsRankingTab.rankAt(teams,1),1);
    // Even two top-ranked teams cannot receive fabricated gold/silver.
    expect(TeamsRankingTab.podiumIsAmbiguous(teams),isTrue);
  });

  testWidgets('tie in top three stays a list instead of arbitrary medals',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>(
      create: (_) => _AnonymousAuth(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TeamsRankingTab(
          teamsStream: Stream.value([
            _team('a','First','Aswan','Football',points:12),
            _team('b','Second','Aswan','Football',points:12),
            _team('c','Third','Aswan','Football',points:10),
          ]),
          selectedLocation: 'Aswan',
          selectedSport: 'Football',
          onRetry: () {},
        )),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('First'),findsOneWidget);
    expect(find.text('Second'),findsOneWidget);
    expect(find.text('Third'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('retired 1v1 winner appears only as a historical title: ${locale.languageCode}',
        (tester) async {
      final team = _team('legacy-winner', 'Nile Stars', 'Aswan', 'Football');
      var lookups = 0;
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>(
        create: (_) => _AnonymousAuth(),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TeamsRankingTab(
            teamsStream: Stream.value([team]),
            selectedLocation: 'Aswan',
            selectedSport: 'Football',
            onRetry: () {},
            historical1v1TitleLookup: (teamId) async {
              expect(teamId, 'legacy-winner');
              lookups++;
              return true;
            },
          )),
        ),
      ));
      await tester.pumpAndSettle();
      final isArabic = locale.languageCode == 'ar';
      final label = isArabic ? 'لقب تاريخي' : 'Legacy title';
      expect(find.text(label), findsOneWidget);
      expect(find.text('بطل 1v1'), findsNothing);
      final tooltip = tester.widget<Tooltip>(find.ancestor(
          of: find.text(label), matching: find.byType(Tooltip)));
      expect(tooltip.message, contains(isArabic ? 'المتوقفة' : 'retired'));
      expect(lookups, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('teams without legacy titles have no former-trophy badge',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>(
      create: (_) => _AnonymousAuth(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TeamsRankingTab(
          teamsStream: Stream.value([
            _team('new-team', 'Newcomers', 'Aswan', 'Football'),
          ]),
          selectedLocation: 'Aswan',
          selectedSport: 'Football',
          onRetry: () {},
          historical1v1TitleLookup: (_) async => false,
        )),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Legacy title'), findsNothing);
    expect(find.text('بطل 1v1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
