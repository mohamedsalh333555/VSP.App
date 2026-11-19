import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/vsp_1v1_trophy_badge.dart';

Widget _screen(Widget child, Locale locale) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  home: Scaffold(body: Center(child: child)),
);

void main() {
  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('retired trophy label is visible: ${locale.languageCode}',
        (tester) async {
      final ar = locale.languageCode == 'ar';
      await tester.pumpWidget(_screen(
        const Vsp1v1TrophyBadge(titles: 2), locale));
      expect(find.text(ar
          ? '🏆 ×2 · تاريخي' : '🏆 ×2 · Legacy'), findsOneWidget);
      final tip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tip.message, contains(ar ? 'التاريخية' : 'Historical'));
      expect(find.text('بطل 1v1'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('zero historical titles do not invent a trophy',
      (tester) async {
    await tester.pumpWidget(_screen(
      const Vsp1v1TrophyBadge(titles: 0), const Locale('en')));
    expect(find.byType(Tooltip), findsNothing);
    expect(find.textContaining('🏆'), findsNothing);
  });

  testWidgets('previous account title stays hidden on user switch',
      (tester) async {
    final former = Completer<int>();
    final next = Completer<int>();
    Future<int> load(String id) =>
        id == 'former-user' ? former.future : next.future;
    Widget profile(String id) => _screen(
      Vsp1v1UserTrophyBadge(userId: id, loadTitles: load),
      const Locale('en'),
    );
    await tester.pumpWidget(profile('former-user'));
    await tester.pumpWidget(profile('next-user'));
    former.complete(3);
    await tester.pump();
    expect(find.textContaining('Legacy'), findsNothing);
    next.complete(1);
    await tester.pumpAndSettle();
    expect(find.text('🏆 1 · Legacy'), findsOneWidget);
    expect(find.textContaining('🏆 ×3'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
