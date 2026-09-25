import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/vsp_1v1_trophy_badge.dart';

void main() {
  group('Vsp1v1TrophyBadge Widget Tests', () {
    testWidgets('renders nothing when titles is 0 or negative', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Vsp1v1TrophyBadge(titles: 0),
          ),
        ),
      );

      expect(find.byType(Vsp1v1TrophyBadge), findsOneWidget);
      expect(find.textContaining('🏆'), findsNothing);
    });

    testWidgets('renders 🏆 1 when titles is 1', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Vsp1v1TrophyBadge(titles: 1),
          ),
        ),
      );

      expect(find.text('🏆 1'), findsOneWidget);
    });

    testWidgets('renders 🏆 ×2 when titles is 2', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Vsp1v1TrophyBadge(titles: 2),
          ),
        ),
      );

      expect(find.text('🏆 ×2'), findsOneWidget);
    });

    testWidgets('renders 🏆 ×5 when titles is 5', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Vsp1v1TrophyBadge(titles: 5),
          ),
        ),
      );

      expect(find.text('🏆 ×5'), findsOneWidget);
    });
  });
}
