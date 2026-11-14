import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_calendar_modal.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  Widget host(
    Locale locale,
    ValueChanged<DateTime> onDateSelected, {
    DateTime? initialDate,
    DateTime? operationalBaseDate,
  }) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBookingCalendarModal(
                context: context,
                initialDate: initialDate ?? DateTime(2026, 11, 13),
                operationalBaseDate: operationalBaseDate ?? DateTime(2026, 11, 13),
                onDateSelected: onDateSelected,
              ),
              child: const Text('Open calendar'),
            ),
          ),
        ),
      );

  Finder dateWithLabel(String label) => find.byWidgetPredicate(
    (widget) => widget is Semantics &&
        (widget.properties.label?.contains(label) ?? false),
  );

  testWidgets('past date is disabled; future day is announced and applied in English', (tester) async {
    final semantics = tester.ensureSemantics();
    DateTime? selected;
    await tester.pumpWidget(host(const Locale('en'), (value) => selected = value));
    await tester.tap(find.text('Open calendar'));
    await tester.pumpAndSettle();

    final past = dateWithLabel('Booking date: Thursday, 12 November 2026');
    final today = dateWithLabel('Booking date: Friday, 13 November 2026');
    final next = dateWithLabel('Booking date: Saturday, 14 November 2026');

    expect(past, findsOneWidget);
    expect(tester.widget<Semantics>(past).properties.enabled, isFalse);
    expect(today, findsOneWidget);
    expect(tester.widget<Semantics>(today).properties.selected, isTrue);
    expect(next, findsOneWidget);
    expect(tester.widget<Semantics>(next).properties.enabled, isTrue);

    await tester.tap(next);
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(selected, isNotNull);
    expect(selected!.year, 2026);
    expect(selected!.month, 11);
    expect(selected!.day, 14);
    semantics.dispose();
  });

  testWidgets('Arabic calendar dates are labeled and RTL is preserved', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(const Locale('ar'), (_) {}));
    await tester.tap(find.text('Open calendar'));
    await tester.pumpAndSettle();

    final dates = tester.widgetList<Semantics>(find.byType(Semantics))
        .where((node) =>
            node.properties.label?.startsWith('تاريخ الحجز:') ?? false)
        .toList();

    expect(Directionality.of(tester.element(find.byType(Dialog))), TextDirection.rtl);
    expect(dates.length, greaterThan(5));
    expect(dates.where((node) => node.properties.selected == true), hasLength(1));
    expect(dates.where((node) => node.properties.enabled == false), isNotEmpty);
    semantics.dispose();
  });

  for (final initialDay in [DateTime(2026, 11, 12), DateTime(2027, 7, 1)]) {
    testWidgets('stale or out-of-range initial date cannot be applied: $initialDay', (tester) async {
      final semantics = tester.ensureSemantics();
      DateTime? selected;
      await tester.pumpWidget(host(
        const Locale('en'),
        (value) => selected = value,
        initialDate: initialDay,
      ));
      await tester.tap(find.text('Open calendar'));
      await tester.pumpAndSettle();

      final current = dateWithLabel('Booking date: Friday, 13 November 2026');
      expect(tester.widget<Semantics>(current).properties.selected, isTrue);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(selected, DateTime(2026, 11, 13));
      semantics.dispose();
    });
  }

  testWidgets('six-week month renders last day with full-height touch target', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(
      const Locale('en'),
      (_) {},
      initialDate: DateTime(2026, 8, 1),
      operationalBaseDate: DateTime(2026, 8, 1),
    ));
    await tester.tap(find.text('Open calendar'));
    await tester.pumpAndSettle();

    final lastDay = dateWithLabel('Booking date: Monday, 31 August 2026');
    expect(lastDay, findsOneWidget);
    expect(tester.getSize(lastDay).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
