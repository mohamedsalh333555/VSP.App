import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancellation validates booking identity before financial operations', () {
    final source = File(
      'lib/core/repositories/booking/booking_cancellation_coordinator.dart',
    ).readAsStringSync();

    expect(source, contains('bookingId.trim().isEmpty'));
    expect(source, contains('booking.id != bookingId'));
    expect(source, contains("manualResult is! Map || manualResult['success'] != true"));
    expect(
      "rpcRes is! Map || rpcRes['success'] != true".allMatches(source).length,
      2,
      reason: 'Both refund cancellation RPC paths must require confirmed success.',
    );

    final identityCheck = source.indexOf('booking.id != bookingId');
    final manualRpc = source.indexOf("'owner_cancel_manual_booking_atomic'");
    final refundFunction = source.indexOf("'process_paymob_refund'");
    expect(identityCheck, greaterThanOrEqualTo(0));
    expect(identityCheck, lessThan(manualRpc));
    expect(identityCheck, lessThan(refundFunction));
  });
}
