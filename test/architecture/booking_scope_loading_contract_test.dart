import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identity switch immediately invalidates sensitive booking caches', () {
    final source = File('lib/core/providers/booking_provider.dart')
        .readAsStringSync();
    final from = source.indexOf('Future<bool> loadUserBookings(');
    final to = source.indexOf('/// Cancel a booking', from);
    final readScope = source.substring(from, to);

    expect('_currentBooking = null;'.allMatches(readScope).length, 2);
    expect('_publicMatches = [];'.allMatches(readScope).length, 2);
    expect('_userBookings = [];'.allMatches(readScope).length, 2);
    expect('_userBookingLoadCount = 0;'.allMatches(readScope).length,
        greaterThanOrEqualTo(3));
    expect('_ownerBookingLoadCount = 0;'.allMatches(readScope).length,
        greaterThanOrEqualTo(3));
    expect(readScope, contains('_activeUserId == userId'));
    expect(readScope, contains('_activeOwnerId == ownerId'));
  });
}
