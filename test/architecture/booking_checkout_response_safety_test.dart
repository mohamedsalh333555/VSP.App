import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('atomic booking RPC rejects malformed and explicitly failed results', () {
    final source = File(
      'lib/core/repositories/booking/booking_creation_coordinator.dart',
    ).readAsStringSync();
    expect(source, contains("rpcResult['code'] ?? rpcResult['error']"));
    expect(source, contains("rpcResult is! Map || rpcResult['success'] != true"));
    final guard = source.indexOf("rpcResult is! Map || rpcResult['success'] != true");
    final bookingId = source.indexOf("final bookingId = rpcResult['booking_id']");
    expect(guard, greaterThanOrEqualTo(0));
    expect(bookingId, greaterThan(guard));
  });

  test('checkout does not silently create a new booking on failed resume', () {
    final source = File(
      'lib/features/player/services/payment_checkout_coordinator.dart',
    ).readAsStringSync();
    final resume = source.indexOf('final restored = await fetchBookingById(existingBookingId)');
    final reject = source.indexOf("throw StateError('Unable to resume the existing payment booking')");
    final create = source.indexOf('await createBooking(draft, userId)');
    expect(resume, greaterThanOrEqualTo(0));
    expect(reject, greaterThan(resume));
    expect(create, greaterThan(reject));
  });
}
