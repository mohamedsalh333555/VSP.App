import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkout validates draft before destructive stale booking cleanup', () {
    final source = File(
      'lib/features/player/services/payment_checkout_coordinator.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<Booking?> resolveInitialBooking(');
    expect(start, greaterThanOrEqualTo(0));
    final body = source.substring(start);
    final validate = body.indexOf('bookingDraft.validate()');
    final cleanup = body.indexOf('await cleanupStaleBookings(');
    final create = body.indexOf('await createBooking(draft, userId)');
    expect(validate, greaterThanOrEqualTo(0));
    expect(cleanup, greaterThan(validate));
    expect(create, greaterThan(cleanup));
  });
}
