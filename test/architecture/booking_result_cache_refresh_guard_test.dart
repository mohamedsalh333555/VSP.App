import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('result refreshes cached booking on success or dispute without undoing outcome', () {
    final source = File('lib/core/providers/booking_provider.dart').readAsStringSync();
    final start = source.indexOf('Future<bool> submitMatchResult(');
    final end = source.indexOf('/// Update payment status', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains('if (!success) {'));
    expect(method.indexOf('getBookingByIdStrict(bookingId)'),
        lessThan(method.indexOf('if (!success) {')));
    expect(method, contains('getBookingByIdStrict(bookingId)'));
    expect(method, contains('BookingListModifier.updateBooking(_userBookings, updated)'));
    expect(method, contains('_currentBooking = updated;'));
    expect(method, contains('catch (_)'));
    expect(method, contains('return success;'));
    // An early success return is intentionally allowed when the account
    // switched while the RPC was outstanding. For the active account, the
    // normal exit must follow the strict reconciliation read.
    expect(method, contains('operationScope != _bookingScopeGeneration'));
    expect(method.indexOf('getBookingByIdStrict(bookingId)'),
        lessThan(method.lastIndexOf('return success;')));
  });
}
