import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking creation rejects unusable RPC booking identifiers', () {
    final source = File(
      'lib/core/repositories/booking/booking_creation_coordinator.dart',
    ).readAsStringSync();

    expect(source, contains("rpcResult['booking_id']?.toString()"));
    expect(source, contains("e.code == '23P01'"),
        reason: 'PostgreSQL exclusion violations indicate overlapping slots.');
    expect(source, contains("e.code == '23505'"));
    expect(source, contains('bookingId == null'));
    expect(source, contains('bookingId.trim().isEmpty'));
    expect(source, contains("bookingId == 'null'"));
    expect(
      source.indexOf('bookingId.trim().isEmpty'),
      lessThan(source.indexOf('getBookingById(bookingId)')),
      reason: 'Invalid IDs must be rejected before fetching booking details.',
    );
  });
}
