import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/add_stadium_step1_hours_section.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/add_stadium_step1_location_field.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('AddStadiumStep1LocationField', () {
    testWidgets('shows placeholder text when location is empty', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          AddStadiumStep1LocationField(
            locationController: controller,
            isEditing: false,
            isLocationLoading: false,
            onOpenMapPicker: () {},
            onOpenManualPicker: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tap to select stadium location on map '), findsOneWidget);
    });

    testWidgets('shows location text when controller has value', (tester) async {
      final controller = TextEditingController(text: 'Cairo, Egypt');
      await tester.pumpWidget(
        _wrap(
          AddStadiumStep1LocationField(
            locationController: controller,
            isEditing: false,
            isLocationLoading: false,
            onOpenMapPicker: () {},
            onOpenManualPicker: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cairo, Egypt'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLocationLoading is true', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          AddStadiumStep1LocationField(
            locationController: controller,
            isEditing: false,
            isLocationLoading: true,
            onOpenMapPicker: () {},
            onOpenManualPicker: () {},
          ),
        ),
      );
      // Use pump with duration instead of pumpAndSettle to avoid animation timeout
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('calls onOpenMapPicker when tapped and not editing/loading', (tester) async {
      final controller = TextEditingController();
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          AddStadiumStep1LocationField(
            locationController: controller,
            isEditing: false,
            isLocationLoading: false,
            onOpenMapPicker: () => tapped = true,
            onOpenManualPicker: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(GestureDetector).first);
      expect(tapped, isTrue);
    });

    testWidgets('does not call onOpenMapPicker when isEditing is true', (tester) async {
      final controller = TextEditingController();
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          AddStadiumStep1LocationField(
            locationController: controller,
            isEditing: true,
            isLocationLoading: false,
            onOpenMapPicker: () => tapped = true,
            onOpenManualPicker: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(GestureDetector).first);
      expect(tapped, isFalse);
    });
  });

  group('AddStadiumStep1HoursSection', () {
    Widget buildHoursSection({
      TimeOfDay? startTime,
      TimeOfDay? endTime,
      bool isSplitShift = false,
      List<Map<String, TimeOfDay?>>? breakTimes,
      bool isSplitShiftValid = true,
      Function(bool)? onSelectTime,
      ValueChanged<bool>? onToggleSplitShift,
      Function(int, bool)? onSelectBreakTime,
      VoidCallback? onAddBreak,
      ValueChanged<int>? onRemoveBreak,
    }) {
      return _wrap(
        AddStadiumStep1HoursSection(
          startTime: startTime,
          endTime: endTime,
          isSplitShift: isSplitShift,
          breakTimes: breakTimes ?? [{'start': null, 'end': null}],
          isSplitShiftValid: isSplitShiftValid,
          onSelectTime: onSelectTime ?? (_) {},
          onToggleSplitShift: onToggleSplitShift ?? (_) {},
          onSelectBreakTime: onSelectBreakTime ?? (_, __) {},
          onAddBreak: onAddBreak ?? () {},
          onRemoveBreak: onRemoveBreak ?? (_) {},
        ),
      );
    }

    testWidgets('renders working hours label', (tester) async {
      await tester.pumpWidget(buildHoursSection());
      await tester.pumpAndSettle();
      expect(find.text('Working Hours'), findsOneWidget);
    });

    testWidgets('shows closing time note when endTime is set', (tester) async {
      await tester.pumpWidget(buildHoursSection(
        startTime: const TimeOfDay(hour: 8, minute: 0),
        endTime: const TimeOfDay(hour: 22, minute: 0),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Selecting closing time'), findsOneWidget);
    });

    testWidgets('shows split shift toggle', (tester) async {
      await tester.pumpWidget(buildHoursSection());
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('shows break rows when isSplitShift is true', (tester) async {
      await tester.pumpWidget(buildHoursSection(
        isSplitShift: true,
        breakTimes: [
          {
            'start': const TimeOfDay(hour: 13, minute: 0),
            'end': const TimeOfDay(hour: 14, minute: 0),
          },
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Break 1'), findsOneWidget);
      expect(find.text('Add Another Break'), findsOneWidget);
    });

    testWidgets('shows validation error when isSplitShiftValid is false', (tester) async {
      await tester.pumpWidget(buildHoursSection(
        isSplitShift: true,
        isSplitShiftValid: false,
        breakTimes: [{'start': null, 'end': null}],
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Break hours must fall'), findsOneWidget);
    });

    testWidgets('invokes onToggleSplitShift when switch toggled', (tester) async {
      bool? received;
      await tester.pumpWidget(buildHoursSection(
        onToggleSplitShift: (v) => received = v,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(received, isNotNull);
    });

    testWidgets('calls onAddBreak when add break button tapped', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildHoursSection(
        isSplitShift: true,
        onAddBreak: () => called = true,
        breakTimes: [{'start': null, 'end': null}],
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Another Break'));
      expect(called, isTrue);
    });

    testWidgets('shows two break row labels when two breaks provided', (tester) async {
      await tester.pumpWidget(buildHoursSection(
        isSplitShift: true,
        breakTimes: [
          {'start': null, 'end': null},
          {'start': null, 'end': null},
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Break 1'), findsOneWidget);
      expect(find.text('Break 2'), findsOneWidget);
    });
  });

  group('Time formatting unit tests', () {
    String formatTime12h(TimeOfDay t) {
      final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
      final period = t.period == DayPeriod.am ? 'AM' : 'PM';
      final minute = t.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    }

    test('midnight shown as 12:00 AM', () {
      expect(formatTime12h(const TimeOfDay(hour: 0, minute: 0)), equals('12:00 AM'));
    });

    test('noon shown as 12:00 PM', () {
      expect(formatTime12h(const TimeOfDay(hour: 12, minute: 0)), equals('12:00 PM'));
    });

    test('3:30 PM shown correctly', () {
      expect(formatTime12h(const TimeOfDay(hour: 15, minute: 30)), equals('3:30 PM'));
    });

    test('9:05 AM shown with zero-padded minutes', () {
      expect(formatTime12h(const TimeOfDay(hour: 9, minute: 5)), equals('9:05 AM'));
    });
  });
}
