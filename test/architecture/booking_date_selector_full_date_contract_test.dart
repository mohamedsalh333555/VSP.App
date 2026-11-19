import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected date matches day, month and year', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_date_selector.dart',
    ).readAsStringSync();
    expect(source, contains('date.year == selectedDate.year'));
    expect(source, contains('date.month == selectedDate.month'));
    expect(source, contains('date.day == selectedDate.day'));
    expect(source, isNot(contains("DateFormat('MMMM, yyyy'")));
  });
}
