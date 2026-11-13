import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_date_selector.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  Widget picker({
    required Locale locale,
    required ValueChanged<DateTime> onChanged,
    double textScale = 1,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: BookingDateSelector(
            selectedDate: DateTime(2026, 11, 13),
            operationalBaseDate: DateTime(2026, 11, 13),
            onDateChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('English day chip exposes full date, selected state and tap', (tester) async {
    final semantics = tester.ensureSemantics();
    DateTime? picked;
    await tester.pumpWidget(picker(
      locale: const Locale('en'),
      onChanged: (date) => picked = date,
    ));

    final current = find.bySemanticsLabel(
      RegExp(r'Booking date: Friday, 13 November 2026'),
    );
    expect(current, findsOneWidget);
    final currentWidget = tester.widget<Semantics>(current);
    expect(currentWidget.properties.button, isTrue);
    expect(currentWidget.properties.selected, isTrue);

    final next = find.bySemanticsLabel(
      RegExp(r'Booking date: Saturday, 14 November 2026'),
    );
    expect(next, findsOneWidget);
    expect(tester.widget<Semantics>(next).properties.selected, isFalse);
    await tester.tap(next);
    expect(picked, isNotNull);
    expect(picked!.year, 2026);
    expect(picked!.month, 11);
    expect(picked!.day, 14);
    semantics.dispose();
  });

  testWidgets('Arabic day chips have one selected accessible date', (tester) async {
    final semantics = tester.ensureSemantics();
    DateTime? picked;
    await tester.pumpWidget(picker(
      locale: const Locale('ar'),
      onChanged: (date) => picked = date,
    ));

    final chips = tester.widgetList<Semantics>(find.byType(Semantics))
        .where((widget) =>
            widget.properties.label?.startsWith('تاريخ الحجز:') ?? false)
        .toList();
    expect(chips.length, greaterThanOrEqualTo(2));
    expect(chips.where((widget) => widget.properties.selected == true), hasLength(1));
    expect(chips.every((widget) => widget.properties.button == true), isTrue);

    await tester.tap(find.text('14'));
    expect(picked?.day, 14);
    semantics.dispose();
  });
  for (final locale in [const Locale('ar'), const Locale('en')]) {
    testWidgets('calendar opener is accessible and scales day chips ($locale)', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(picker(locale: locale, onChanged: (_) {}, textScale: 2));
      await tester.pump();

      final label = locale.languageCode == 'ar'
          ? 'فتح تقويم الحجز'
          : 'Open booking calendar';
      final control = find.bySemanticsLabel(RegExp(RegExp.escape(label)));
      expect(control, findsOneWidget);
      final semanticWidget = tester.widget<Semantics>(control);
      expect(semanticWidget.properties.button, isTrue);
      expect(semanticWidget.properties.onTap, isNotNull);
      expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(find.byType(ListView)).height, greaterThanOrEqualTo(140));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
