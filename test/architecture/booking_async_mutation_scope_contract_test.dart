import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('async booking mutations cannot repopulate a different account', () {
    final source = File('lib/core/providers/booking_provider.dart')
        .readAsStringSync();
    const boundaries = <String, String>{
      'createBookingFromDraft(': '/// Create booking directly with a draft',
      'createBooking(BookingDraft': '/// Load user\'s bookings',
      'cancelBooking(': '/// Request booking rescheduling',
      'submitMatchResult(': '/// Update payment status',
      'updatePaymentStatus(': '/// Update manual booking details',
    };

    for (final entry in boundaries.entries) {
      final start = source.indexOf(entry.key);
      final end = source.indexOf(entry.value, start);
      expect(start, greaterThanOrEqualTo(0), reason: entry.key);
      expect(end, greaterThan(start), reason: entry.key);
      final body = source.substring(start, end);
      expect(body, contains('final operationScope = _bookingScopeGeneration;'),
          reason: entry.key);
      expect(body, contains('operationScope != _bookingScopeGeneration'),
          reason: entry.key);
    }
  });
}
