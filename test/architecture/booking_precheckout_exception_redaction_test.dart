import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking preflight redacts location, slot and payment-policy exceptions', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_confirmation_handler.dart',
    ).readAsStringSync();

    expect(source, contains('Location verification fallback to online-preferred (details redacted)'));
    expect(source, contains('Slot availability validation failed (details redacted)'));
    expect(source, contains('Cash booking payment-policy verification failed (details redacted)'));
    expect(source, isNot(contains('VSPLogger.e(\'Error checking slot availability before booking\', e, stack)')));
    expect(source, isNot(contains('fallback to online-preferred: \$e')));
    // Never substitute an unknown booking history with an empty cash booking
    // history when payment eligibility is uncertain.
    expect(source, contains('getUserBookingsDirectlyStrict(userId)'));
    expect(source, contains('No booking was submitted; please try again.'));
  });
}
