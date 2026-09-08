import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/shared/widgets/date_picker/vsp_date_picker_calculator.dart';

void main() {
  group('VspDatePickerCalculator Unit Tests', () {
    test('daysInMonth accurately computes days including leap years', () {
      // Leap years:
      expect(VspDatePickerCalculator.daysInMonth(2024, 2), equals(29));
      expect(VspDatePickerCalculator.daysInMonth(2020, 2), equals(29));
      expect(VspDatePickerCalculator.daysInMonth(2000, 2), equals(29));

      // Non-leap years:
      expect(VspDatePickerCalculator.daysInMonth(2023, 2), equals(28));
      expect(VspDatePickerCalculator.daysInMonth(2022, 2), equals(28));
      expect(VspDatePickerCalculator.daysInMonth(1900, 2), equals(28));

      // 30-day months:
      expect(VspDatePickerCalculator.daysInMonth(2024, 4), equals(30));
      expect(VspDatePickerCalculator.daysInMonth(2024, 6), equals(30));
      expect(VspDatePickerCalculator.daysInMonth(2024, 9), equals(30));
      expect(VspDatePickerCalculator.daysInMonth(2024, 11), equals(30));

      // 31-day months:
      expect(VspDatePickerCalculator.daysInMonth(2024, 1), equals(31));
      expect(VspDatePickerCalculator.daysInMonth(2024, 3), equals(31));
      expect(VspDatePickerCalculator.daysInMonth(2024, 7), equals(31));
      expect(VspDatePickerCalculator.daysInMonth(2024, 8), equals(31));
      expect(VspDatePickerCalculator.daysInMonth(2024, 12), equals(31));

      // Out of range fallbacks:
      expect(VspDatePickerCalculator.daysInMonth(2024, 0), equals(30));
      expect(VspDatePickerCalculator.daysInMonth(2024, 13), equals(30));
    });

    test('generateYears creates descending year range', () {
      final years = VspDatePickerCalculator.generateYears(minYear: 2020, maxYear: 2024);
      expect(years, equals([2024, 2023, 2022, 2021, 2020]));

      expect(VspDatePickerCalculator.generateYears(minYear: 2025, maxYear: 2024), isEmpty);
      expect(VspDatePickerCalculator.generateYears(minYear: 2024, maxYear: 2024), equals([2024]));
    });

    test('getMonthName returns bilingual month labels', () {
      expect(VspDatePickerCalculator.getMonthName(1, isArabic: true), equals('يناير'));
      expect(VspDatePickerCalculator.getMonthName(1, isArabic: false), equals('January'));

      expect(VspDatePickerCalculator.getMonthName(7, isArabic: true), equals('يوليو'));
      expect(VspDatePickerCalculator.getMonthName(7, isArabic: false), equals('July'));

      expect(VspDatePickerCalculator.getMonthName(12, isArabic: true), equals('ديسمبر'));
      expect(VspDatePickerCalculator.getMonthName(12, isArabic: false), equals('December'));

      // Out of bounds:
      expect(VspDatePickerCalculator.getMonthName(99, isArabic: true), equals('99'));
    });

    test('canNavigateToStep enforces sequential selection dependency', () {
      // Step 0: Year always accessible
      expect(VspDatePickerCalculator.canNavigateToStep(targetStep: 0), isTrue);

      // Step 1: Month requires year
      expect(VspDatePickerCalculator.canNavigateToStep(targetStep: 1, selectedYear: null), isFalse);
      expect(VspDatePickerCalculator.canNavigateToStep(targetStep: 1, selectedYear: 2000), isTrue);

      // Step 2: Day requires month
      expect(VspDatePickerCalculator.canNavigateToStep(targetStep: 2, selectedMonth: null), isFalse);
      expect(VspDatePickerCalculator.canNavigateToStep(targetStep: 2, selectedMonth: 5), isTrue);
    });
  });
}
