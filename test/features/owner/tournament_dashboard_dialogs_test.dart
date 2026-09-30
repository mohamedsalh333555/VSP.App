import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/owner/widgets/tournament/tournament_dashboard_bottom_bar.dart';
import 'package:vsp_application/features/owner/widgets/tournament/tournament_dashboard_dialogs.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );
  }

  testWidgets('TournamentDashboardDialogs.showUnpaidTeamsWarning displays properly', (tester) async {
    bool? result;

    await tester.pumpWidget(
      buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await TournamentDashboardDialogs.showUnpaidTeamsWarning(
                context,
                unpaidNames: 'Team A, Team B',
                entryFee: 100.0,
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Team A, Team B'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Understood'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('TournamentDashboardDialogs.showForceStartConfirmation displays properly', (tester) async {
    bool? result;

    await tester.pumpWidget(
      buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await TournamentDashboardDialogs.showForceStartConfirmation(
                context,
                teamCount: 4,
                maxTeams: 8,
              );
            },
            child: const Text('Open Force Start'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Force Start'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('TournamentDashboardBottomBar shows generate draw when open', (tester) async {
    final champ = Championship(
      id: 'c1',
      ownerId: 'o1',
      name: 'Test Cup',
      sportType: 'Football',
      logoUrl: '',
      startDate: DateTime.now().add(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 2)),
      entryFee: 50,
      grandPrize: 500,
      joinedTeams: ['t1', 't2'],
      maxTeams: 8,
      status: 'open',
      type: 'Knockout',
      governorate: 'Cairo',
      rules: '',
    );

    var started = false;

    await tester.pumpWidget(
      buildTestApp(
        TournamentDashboardBottomBar(
          championship: champ,
          isLoading: false,
          onStartTournament: () => started = true,
        ),
      ),
    );

    expect(find.byType(TournamentDashboardBottomBar), findsOneWidget);
    await tester.tap(find.byType(TournamentDashboardBottomBar));
    await tester.pump();
  });

  testWidgets('TournamentDashboardDialogs.showCancelTournamentConfirmation displays warning and refund alert', (tester) async {
    bool? result;

    await tester.pumpWidget(
      buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await TournamentDashboardDialogs.showCancelTournamentConfirmation(
                context,
                tournamentName: 'Ramadan Cup',
                teamsCount: 4,
                paidTeamsCount: 2,
                isTeamLeague: false,
              );
            },
            child: const Text('Open Cancel Dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Cancel Dialog'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Ramadan Cup'), findsOneWidget);
    expect(find.textContaining('2'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm Cancel'), findsOneWidget);

    await tester.tap(find.text('Confirm Cancel'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('TournamentDashboardDialogs.showDeleteTournamentConfirmation displays delete dialog', (tester) async {
    bool? result;

    await tester.pumpWidget(
      buildTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await TournamentDashboardDialogs.showDeleteTournamentConfirmation(
                context,
                tournamentName: 'Empty Cup',
              );
            },
            child: const Text('Open Delete Dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Delete Dialog'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Empty Cup'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}

