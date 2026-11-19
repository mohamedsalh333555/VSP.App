import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly booking picker uses operational date rather than device today', () {
    final modal = File(
      'lib/features/player/widgets/booking/booking_calendar_modal.dart',
    ).readAsStringSync();
    final selector = File(
      'lib/features/player/widgets/booking/booking_date_selector.dart',
    ).readAsStringSync();

    expect(modal, contains('required DateTime operationalBaseDate,'));
    expect(modal, contains('final firstBookableDay = DateTime(operationalBaseDate.year'));
    expect(modal, contains('final isPastDate = date.isBefore(firstBookableDay);'));
    expect(modal, contains('DateTime(firstBookableDay.year, firstBookableDay.month + 3)'));
    expect(selector, contains('operationalBaseDate: operationalBaseDate,'));
  });
}
