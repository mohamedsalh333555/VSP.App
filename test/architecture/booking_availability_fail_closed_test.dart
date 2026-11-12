import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stadium availability failures are not converted to empty schedules', () {
    final source = File(
      'lib/core/repositories/booking/booking_query_coordinator.dart',
    ).readAsStringSync();

    final fetchMethod = RegExp(
      r'Future<List<Booking>> fetchStadiumBookingsDirectly[\s\S]*?'
      r'/// Polls the scoped stadium-slot RPC',
    ).firstMatch(source)?.group(0);

    expect(fetchMethod, isNotNull);
    expect(fetchMethod, contains('rethrow;'));
    expect(fetchMethod, isNot(contains('return [];')));
    final streamStart = source.indexOf('Stream<List<Booking>> getBookingsForStadium(');
    final streamEnd = source.indexOf('/// Fetches unpaid confirmed bookings', streamStart);
    expect(streamStart, greaterThanOrEqualTo(0));
    expect(streamEnd, greaterThan(streamStart));
    final streamBody = source.substring(streamStart, streamEnd);
    expect(streamBody, contains('Error.throwWithStackTrace(e, stack);'));
    expect(streamBody, contains('yield refreshed;'));
    expect(streamBody, isNot(contains('lastVerified')));
    expect(streamBody, isNot(contains('retaining the last verified snapshot')));
  });
}
