import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('direct owner booking reads verify owner and stadium scope', () {
    final source = File(
      'lib/core/repositories/booking/booking_query_coordinator.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'Future<List<Booking>> fetchOwnerBookingsDirectlyStrict(',
    );
    final end = source.indexOf('/// Real-time stream of stadium owner bookings.', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains("booking.ownerId.trim().toLowerCase() == normalizedOwnerId"));
    expect(method, contains('allowedStadiumIds.contains(booking.stadiumId.trim().toLowerCase())'));
    expect(method, contains('normalizedOwnerId.isNotEmpty'));
    expect(method, contains(".eq('owner_id', ownerId)"));
  });
}
