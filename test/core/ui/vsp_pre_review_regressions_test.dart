import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/ui/components/vsp_segmented_control.dart';
import 'package:vsp_application/shared/widgets/vsp_animated_button.dart';
import 'package:vsp_application/shared/widgets/vsp_countdown_timer.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

// Prepared for the final review; execution remains on hold.
void main() {
  for (final language in ['ar', 'en']) {
    testWidgets('segmented actions wrap and remain reachable in $language', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = 0;
      final labels = language == 'ar'
          ? ['البطولات القادمة', 'البطولات الجارية', 'البطولات المنتهية']
          : ['Upcoming tournaments', 'Ongoing tournaments', 'Finished tournaments'];
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: Center(child: StatefulBuilder(
          builder: (context, update) => VSPSegmentedControl(
            labels: labels, selectedIndex: selected,
            onSelected: (value) => update(() => selected = value),
          ),
        ))),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final target in find.byType(InkWell).evaluate()) {
        expect(tester.getSize(find.byWidget(target.widget)).height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.text(labels.last));
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('animated button rests at full size and preserves null callback', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: Center(child: VSPAnimatedButton(text: 'Unavailable')),
    )));
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    final scale = find.descendant(of: find.byType(VSPAnimatedButton), matching: find.byType(ScaleTransition));
    expect(tester.widget<ScaleTransition>(scale).scale.value, 1);
  });
  testWidgets('disabled animated button ignores taps', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: Center(child: VSPAnimatedButton(text: 'Unavailable')),
    )));
    await tester.tap(find.text('Unavailable'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
  });

  testWidgets('Arabic expired countdown reports scheduled time only', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      home: Scaffold(body: VSPCountdownTimer(targetDate: DateTime(2000))),
    ));
    expect(find.text('حان موعد البداية المحدد'), findsOneWidget);
    expect(find.text('Tournament Started!'), findsNothing);
  });

  testWidgets('expired countdown does not claim a server transition', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VSPCountdownTimer(targetDate: DateTime(2000)))));
    expect(find.text('Scheduled start time reached'), findsOneWidget);
    expect(find.text('Tournament Started!'), findsNothing);
  });
}
