import 'dart:async';
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
  testWidgets('legacy medal is clearly historical for Arabic screen readers',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      home: Scaffold(body: Vsp1v1TrophyBadge(titles: 2)),
    ));
    expect(find.text('🏆 ×2'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Semantics &&
          widget.properties.label == 'ألقاب 1 ضد 1 التاريخية: 2'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('historical title lookup does not repeat on a normal rebuild',
      (tester) async {
    var queries = 0;
    Future<int> titles(String userId) async {
      queries++;
      expect(userId, 'player-a');
      return 2;
    }
    Widget screen() => MaterialApp(
      home: Scaffold(
        body: Vsp1v1UserTrophyBadge(userId: 'player-a', loadTitles: titles),
      ),
    );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(queries, 1);
    expect(find.text('🏆 ×2'), findsOneWidget);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(queries, 1);
  });

  testWidgets('account change hides previous medals until verified',
      (tester) async {
    final waiting = Completer<int>();
    var queries = 0;
    Future<int> titles(String userId) {
      queries++;
      return userId == 'player-a' ? Future<int>.value(5) : waiting.future;
    }
    Widget screen(String userId) => MaterialApp(
      home: Scaffold(
        body: Vsp1v1UserTrophyBadge(userId: userId, loadTitles: titles),
      ),
    );

    await tester.pumpWidget(screen('player-a'));
    await tester.pumpAndSettle();
    expect(find.text('🏆 ×5'), findsOneWidget);
    await tester.pumpWidget(screen('player-b'));
    await tester.pump();
    expect(find.text('🏆 ×5'), findsNothing);
    expect(queries, 2);
    waiting.complete(1);
    await tester.pumpAndSettle();
    expect(find.text('🏆 1'), findsOneWidget);
    expect(find.text('🏆 ×5'), findsNothing);
  });

}
