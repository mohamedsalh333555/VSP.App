import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('date selector does not promise availability without slot data', () {
    final selector = File(
      'lib/features/player/widgets/booking/booking_date_selector.dart',
    ).readAsStringSync();
    expect(selector, contains('اختيار اليوم لا يعني توفر مواعيد'));
    expect(selector, contains('Selecting a date does not guarantee availability'));
    expect(selector, contains('onDateChanged(date)'));
  });

  test('calendar blocks past dates', () {
    final calendar = File(
      'lib/features/player/widgets/booking/booking_calendar_modal.dart',
    ).readAsStringSync();
    expect(calendar, contains('onTap: isPastDate'));
    expect(calendar, contains('tempSelectedDate = date;'));
  });
}
