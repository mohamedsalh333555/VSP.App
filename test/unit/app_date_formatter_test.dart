import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vsp_application/core/utils/app_date_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('en', null);
  });

  group('AppDateFormatter Tests', () {
    final testDate = DateTime(2026, 8, 15, 20, 30); // 8:30 PM on Aug 15, 2026

    test('formatFullDate in English', () {
      final formatted = AppDateFormatter.formatFullDate(testDate, 'en');
      expect(formatted, contains('15'));
      expect(formatted, contains('Aug'));
      expect(formatted, contains('2026'));
    });

    test('formatHourMin formats AM and PM correctly', () {
      expect(AppDateFormatter.formatHourMin(20, 30, false), equals('8:30 PM'));
      expect(AppDateFormatter.formatHourMin(8, 30, false), equals('8:30 AM'));
      expect(AppDateFormatter.formatHourMin(0, 0, false), equals('12:00 AM'));
      expect(AppDateFormatter.formatHourMin(12, 0, false), equals('12:00 PM'));

      expect(AppDateFormatter.formatHourMin(20, 30, true), equals('8:30 م'));
      expect(AppDateFormatter.formatHourMin(8, 30, true), equals('8:30 ص'));
    });

    test('formatTimeOfDay formats correctly', () {
      const eveningTime = TimeOfDay(hour: 21, minute: 15);
      expect(AppDateFormatter.formatTimeOfDay(eveningTime, 'N/A', false), equals('9:15 PM'));
      expect(AppDateFormatter.formatTimeOfDay(eveningTime, 'N/A', true), equals('9:15 م'));
      expect(AppDateFormatter.formatTimeOfDay(null, 'غير محدد', true), equals('غير محدد'));
    });
  });
}
