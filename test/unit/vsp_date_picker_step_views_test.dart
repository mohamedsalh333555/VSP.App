import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/shared/widgets/date_picker/vsp_date_picker_step_views.dart';

void main() {
  group('VspDatePickerStepViews Widget Tests', () {
    testWidgets('VspDatePickerYearStep renders years list and handles selection', (tester) async {
      int? selectedYear;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VspDatePickerYearStep(
              minYear: 2020,
              maxYear: 2024,
              selectedYear: 2022,
              onYearSelected: (year) => selectedYear = year,
            ),
          ),
        ),
      );

      expect(find.text('2024'), findsOneWidget);
      expect(find.text('2022'), findsOneWidget);

      await tester.tap(find.text('2024'));
      await tester.pump();
      expect(selectedYear, 2024);
    });

    testWidgets('VspDatePickerMonthStep renders months list and handles selection', (tester) async {
      int? selectedMonth;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VspDatePickerMonthStep(
              selectedMonth: 5,
              isAr: false,
              onMonthSelected: (month) => selectedMonth = month,
            ),
          ),
        ),
      );

      expect(find.text('May'), findsOneWidget);
      await tester.tap(find.text('May'));
      await tester.pump();
      expect(selectedMonth, 5);
    });

    testWidgets('VspDatePickerDayStep renders days and handles selection', (tester) async {
      int? selectedDay;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VspDatePickerDayStep(
              selectedYear: 2026,
              selectedMonth: 2,
              selectedDay: 1,
              onDaySelected: (day) => selectedDay = day,
            ),
          ),
        ),
      );

      expect(find.text('01'), findsOneWidget);
      await tester.tap(find.text('01'));
      await tester.pump();
      expect(selectedDay, 1);
    });
  });
}
