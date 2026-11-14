import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly calendar header and selected date wrap at large scale', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_calendar_modal.dart',
    ).readAsStringSync();
    expect(source, contains('DateFormat(\'MMMM yyyy\''));
    expect(source, contains('textAlign: TextAlign.center,'));
    expect(source, contains('softWrap: true'));
    final dateLabel = source.substring(
      source.indexOf("'Booking Date: '"),
      source.indexOf('const SizedBox(height: VSPSpacing.md)', source.indexOf("'Booking Date: '")),
    );
    expect(dateLabel, isNot(contains('TextOverflow.ellipsis')));
    expect(source, contains('SingleChildScrollView('));
  });

  test('booking date trigger can wrap long translated month names', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_date_selector.dart',
    ).readAsStringSync();
    final firstMonth = source.indexOf("DateFormat('MMMM yyyy', Localizations.localeOf(context)");
    expect(firstMonth, greaterThanOrEqualTo(0));
    expect(source.substring(firstMonth, firstMonth + 240), contains('softWrap: true'));
    expect(source, contains('constraints: const BoxConstraints(minHeight: 48)'));
  });
}
