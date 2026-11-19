import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('realtime owner booking streams filter rows by owner identity', () {
    final source = File(
      'lib/core/repositories/booking/booking_query_coordinator.dart',
    ).readAsStringSync();
    final start = source.indexOf('Stream<List<Booking>> getOwnerBookings(');
    final end = source.indexOf('/// Fetches a single booking by ID.', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains('if (normalizedOwnerId.isEmpty)'));
    expect(method, contains('b.ownerId.trim().toLowerCase() != normalizedOwnerId'));
    expect(method, contains(".eq('owner_id', ownerId)"));
  });

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
  test('owner scope is enforced before optional stadium IDs are applied', () {
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
    expect(method, contains('if (normalizedOwnerId.isEmpty) return <Booking>[];'));
    expect(method, contains(".select().eq('owner_id', ownerId)"));
    expect(method, contains("query = query.inFilter('stadium_id', stadiumIds)"));
    expect(
      method.indexOf(".select().eq('owner_id', ownerId)"),
      lessThan(method.indexOf("query = query.inFilter('stadium_id', stadiumIds)")),
    );
    expect(
      method,
      isNot(contains(".select().inFilter('stadium_id', stadiumIds)")),
    );
  });

  test('player booking reads reject blank identity before querying or streaming', () {
    final source = File(
      'lib/core/repositories/booking/booking_query_coordinator.dart',
    ).readAsStringSync();
    for (final signature in <String>[
      'Stream<List<Booking>> getUserBookings(String userId) async* {',
      'Stream<List<Booking>> getUpcomingBookings(String userId) async* {',
      'Stream<List<Booking>> getBookingHistory(String userId) async* {',
      'Future<List<Booking>> getUnpaidBookingsForUser(String userId) async {',
    ]) {
      final start = source.indexOf(signature);
      expect(start, greaterThanOrEqualTo(0), reason: signature);
      final body = source.substring(start + signature.length);
      final guard = body.indexOf('if (userId.trim().isEmpty)');
      final query = body.indexOf(".from('bookings')");
      expect(guard, greaterThanOrEqualTo(0), reason: signature);
      expect(query, greaterThan(guard), reason: signature);
      expect(body.substring(guard, query), anyOf(contains('return;'), contains('return <Booking>[];')));
    }
  });

}
