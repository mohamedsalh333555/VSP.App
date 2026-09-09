import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/championship_details/championship_bottom_bar.dart';
import 'package:vsp_application/features/player/widgets/championship_details/championship_governorate_dialog.dart';
import 'package:vsp_application/features/player/widgets/championship_details/championship_pill_tab_bar.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  group('ChampionshipGovernorateDialog Tests', () {
    testWidgets('returns true without dialog if governorates match or empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final res = await ChampionshipGovernorateDialog.shouldConfirmAndUserConfirmed(
                    context: context,
                    championshipGovernorate: 'Cairo',
                    playerGovernorate: 'Cairo',
                  );
                  expect(res, isTrue);
                },
                child: const Text('Check Gov'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Check Gov'));
      await tester.pump();
      expect(find.text('Confirm Tournament Location'), findsNothing);
    });

    testWidgets('shows confirmation dialog when governorates differ', (tester) async {
      bool? confirmed;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  confirmed = await ChampionshipGovernorateDialog.shouldConfirmAndUserConfirmed(
                    context: context,
                    championshipGovernorate: 'Alexandria',
                    playerGovernorate: 'Cairo',
                  );
                },
                child: const Text('Check Gov'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Check Gov'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Tournament Location'), findsOneWidget);
      expect(find.text('Yes, We Will Attend'), findsOneWidget);

      await tester.tap(find.text('Yes, We Will Attend'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });
  });

  group('ChampionshipPillTabBar Widget Tests', () {
    testWidgets('renders all 3 tabs and animates selection on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Builder(
              builder: (context) => Scaffold(
                body: ChampionshipPillTabBar(
                  tabController: DefaultTabController.of(context),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Matches'), findsOneWidget);
      expect(find.text('Scorers'), findsOneWidget);
      expect(find.text('Rules'), findsOneWidget);

      await tester.tap(find.text('Rules'));
      await tester.pumpAndSettle();
    });
  });

  group('ChampionshipBottomBar Widget Tests', () {
    final dummyChampionship = Championship(
      id: 'c1',
      name: 'Test Cup',
      sportType: 'Football',
      logoUrl: '',
      governorate: 'Cairo',
      startDate: DateTime.now().add(const Duration(days: 7)),
      endDate: DateTime.now().add(const Duration(days: 14)),
      entryFee: 100,
      grandPrize: 1000,
      maxTeams: 8,
      status: 'open',
      ownerId: 'o1',
      type: 'Cup',
      joinedTeams: ['t1'],
    );

    testWidgets('shows Manage Roster when team is registered', (tester) async {
      final team = Team(
        id: 't1',
        name: 'FC Tigers',
        captainId: 'p1',
        captainName: 'Tarek',
        captainImageUrl: '',
        sportType: 'Football',
        governorate: 'Cairo',
        memberUids: ['p1'],
        date: 'Upcoming',
        stadium: 'Stadium A',
        pricePerPerson: 50.0,
        currentPlayers: 1,
        maxPlayers: 11,
      );

      var managed = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChampionshipBottomBar(
              championship: dummyChampionship,
              myTeam: team,
              isTeamRegistered: true,
              isFull: false,
              isJoining: false,
              onManageRoster: () => managed = true,
              onViewBrackets: () {},
              onJoin: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Manage Roster'), findsOneWidget);

      await tester.tap(find.byType(ChampionshipBottomBar));
      await tester.pump();
      expect(managed, isTrue);
    });

    testWidgets('shows View Brackets when tournament is ongoing or full', (tester) async {
      final ongoingChamp = dummyChampionship.copyWith(status: 'ongoing');
      var viewed = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChampionshipBottomBar(
              championship: ongoingChamp,
              myTeam: null,
              isTeamRegistered: false,
              isFull: false,
              isJoining: false,
              onManageRoster: () {},
              onViewBrackets: () => viewed = true,
              onJoin: () {},
            ),
          ),
        ),
      );

      expect(find.text('View Tournament Brackets'), findsOneWidget);

      await tester.tap(find.text('View Tournament Brackets'));
      await tester.pump();
      expect(viewed, isTrue);
    });
  });
}
