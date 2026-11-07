import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful cancellation preserves history and active booking state', () {
    final source = File('lib/core/providers/booking_provider.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<bool> cancelBooking(');
    final end = source.indexOf('Future<bool> requestReschedule(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final cancel = source.substring(start, end);
    expect(cancel, contains('if (_cancellingIds.contains(bookingId)) return false;'));
    expect(cancel.indexOf('if (_cancellingIds.contains(bookingId))'),
        lessThan(cancel.indexOf('_repository.cancelBooking(bookingId)')));
    expect(cancel, contains('_cancellingIds.remove(bookingId)'));
    expect(cancel, contains('BookingListModifier.updateBooking(_userBookings, updatedBooking)'));
    expect(cancel, isNot(contains('BookingListModifier.removeBooking(_userBookings, bookingId)')));
    expect(cancel, contains('_currentBooking = updatedBooking'));
    expect(cancel, contains('copyWith(status: BookingStatus.cancelled)'));
    expect(
      RegExp(r'_currentBooking!\.copyWith\(status: BookingStatus\.cancelled\)')
          .allMatches(cancel).length,
      2,
    );
  });
}
