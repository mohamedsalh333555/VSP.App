import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/tournament/tournament_manual_team_options_section.dart';
import 'package:vsp_application/features/owner/widgets/tournament/tournament_manual_team_roster_section.dart';
import 'package:vsp_application/features/owner/widgets/tournament/tournament_manual_team_service.dart';

void main() {
  group('TournamentManualTeamService Tests', () {
    test('instantiates safely without Supabase initialized', () {
      final service = TournamentManualTeamService();
      expect(service, isNotNull);
    });
  });

  group('TournamentManualTeamOptionsSection Widget Tests', () {
    testWidgets('renders payment status toggle and shirt color choices', (tester) async {
      bool? updatedStatus;
      String? updatedColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TournamentManualTeamOptionsSection(
              isPaidOnCreation: true,
              onPaymentStatusChanged: (val) => updatedStatus = val,
              selectedPrimaryColor: '#FFFFFF',
              onColorSelected: (val) => updatedColor = val,
            ),
          ),
        ),
      );

      expect(find.text('Paid '), findsOneWidget);
      expect(find.text('Pending '), findsOneWidget);

      await tester.tap(find.text('Pending '));
      await tester.pump();
      expect(updatedStatus, isFalse);

      // Tap one of the color circular containers
      final colorItems = find.byType(GestureDetector);
      expect(colorItems, findsWidgets);
      // Tap one of the later gesture detectors (shirt color item)
      await tester.tap(colorItems.at(3));
      await tester.pump();
      expect(updatedColor, isNotNull);
    });
  });

  group('TournamentManualTeamRosterSection Widget Tests', () {
    testWidgets('renders input, counter and fires callbacks', (tester) async {
      final controller = TextEditingController();
      var added = false;
      String? removed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TournamentManualTeamRosterSection(
              playerInputCtrl: controller,
              offlinePlayerNames: ['Player 1', 'Player 2'],
              onAddPlayer: () => added = true,
              onRemovePlayer: (name) => removed = name,
              onChanged: () {},
            ),
          ),
        ),
      );

      expect(find.text('2 / 12'), findsOneWidget);
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.textContaining('Add 3 more players'), findsOneWidget);

      // Tap add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(added, isTrue);

      // Tap remove chip icon
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(removed, equals('Player 1'));
    });
  });
}
