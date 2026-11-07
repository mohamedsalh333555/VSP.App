import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful result refreshes cached booking without undoing success', () {
    final source = File('lib/core/providers/booking_provider.dart').readAsStringSync();
    final start = source.indexOf('Future<bool> submitMatchResult(');
    final end = source.indexOf('/// Update payment status', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains('if (success) {'));
    expect(method, contains('getBookingByIdStrict(bookingId)'));
    expect(method, contains('BookingListModifier.updateBooking(_userBookings, updated)'));
    expect(method, contains('_currentBooking = updated;'));
    expect(method, contains('catch (refreshError)'));
    expect(method, contains('return success;'));
    expect(method.indexOf('getBookingByIdStrict(bookingId)'),
        lessThan(method.indexOf('return success;')));
  });
}
