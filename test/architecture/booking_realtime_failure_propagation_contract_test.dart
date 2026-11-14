import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking streams propagate errors instead of hiding failed refreshes',
      () {
    final source = File(
      'lib/core/repositories/booking/booking_query_coordinator.dart',
    ).readAsStringSync();
    for (final tag in <String>[
      'Upcoming booking realtime failed (details redacted)',
      'Booking history realtime failed (details redacted)',
      'Match detail realtime failed (details redacted)',
    ]) {
      final i = source.indexOf(tag);
      expect(i, greaterThanOrEqualTo(0));
      expect(source.substring(i, i + 210),
          contains('Error.throwWithStackTrace(error, stack);'));
    }
    expect(source, contains('TimeoutException(\'Match details realtime timeout\')'));
    expect(source, isNot(contains('onTimeout: (sink) => sink.add([])')));
  });
}
