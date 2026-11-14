import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('upcoming and history timeout refreshes preserve verified empty results', () {
    final source = File(
      'lib/core/repositories/booking/booking_query_coordinator.dart',
    ).readAsStringSync();

    for (final streamMethod in ['getUpcomingBookings', 'getBookingHistory']) {
      final start = source.indexOf('Stream<List<Booking>> $streamMethod(');
      expect(start, greaterThanOrEqualTo(0), reason: streamMethod);
      final nextMethod = source.indexOf('\n  ///', start + 1);
      final body = source.substring(
        start,
        nextMethod < 0 ? source.length : nextMethod,
      );
      final timeout = body.substring(body.indexOf('onTimeout: (sink) async {'));
      expect(timeout, contains('getUserBookingsDirectlyStrict(userId)'));
      expect(timeout, contains('sink.add('));
      expect(timeout, isNot(contains('if (refreshed.isNotEmpty)')));
      expect(timeout, isNot(contains('getUserBookingsDirectly(userId)')));
    }
  });
}
