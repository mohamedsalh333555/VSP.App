import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking creation rejects unusable RPC booking identifiers', () {
    final source = File(
      'lib/core/repositories/booking/booking_creation_coordinator.dart',
    ).readAsStringSync();

    expect(source, contains("throw ArgumentError('كود التحدي مطلوب لإتمام حجز التحدي.')"));
    expect(source.indexOf("throw ArgumentError('كود التحدي مطلوب"),
        lessThan(source.indexOf("_supabase.rpc('create_booking_atomic'")),
        reason: 'Challenge bookings without a code must never reach generic booking RPC.');
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
