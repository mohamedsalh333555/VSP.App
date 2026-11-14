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

Team _team(String id, String name, String governorate, String sport) => Team(
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
}
