import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking provider feedback never renders raw provider errors', () {
    final src = File('lib/core/providers/booking_provider.dart')
        .readAsStringSync();
    for (final unsafe in <String>[
      'Failed to create booking: \$e',
      'Error submitting result: \$e',
      '_errorMessage = e.toString()',
      'debugPrintStack(stackTrace:',
      'refresh failed: \$refreshError',
      'Booking payment-status update failed: \$error',
    ]) {
      expect(src, isNot(contains(unsafe)), reason: 'Unsafe: $unsafe');
    }
    expect(
      'BookingListModifier.formatCreationError(e)'.allMatches(src).length,
      greaterThanOrEqualTo(3),
    );
    expect(src, contains('Booking payment-status update failed (details redacted)'));
    expect(src, contains('Cancelled booking refresh failed (details redacted)'));
    expect(src, contains('تعذر تحديث بيانات الحجز حاليًا.'));
  });

  test('draft storage must never log raw shared-preferences errors', () {
    final src = File(
      'lib/core/providers/booking/booking_draft_storage.dart',
    ).readAsStringSync();
    expect('details redacted'.allMatches(src).length, 3);
    expect(src, isNot(contains('draft: \$e')));
  });
}
