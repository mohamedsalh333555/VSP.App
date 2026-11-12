import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stadium booking RPC uses calendar-day bounds across DST', () {
    final source = File(
      'lib/core/repositories/booking/booking_query_coordinator.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'Future<List<Booking>> fetchStadiumBookingsDirectly(',
    );
    final end = source.indexOf(
      '/// Polls the scoped stadium-slot RPC',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final fetch = source.substring(start, end);
    expect(
      fetch,
      contains('final startOfDay = DateTime(date.year, date.month, date.day);'),
    );
    expect(
      fetch,
      contains('final endOfDay = DateTime(date.year, date.month, date.day + 2);'),
    );
    expect(fetch, isNot(contains('startOfDay.add(const Duration(days: 2))')));
    // Guard against a literal backslash-n accidentally commenting out the
    // variable declaration while still satisfying a substring assertion.
    expect(
      fetch.split('\n').map((line) => line.trim()),
      contains('final endOfDay = DateTime(date.year, date.month, date.day + 2);'),
    );
    expect(fetch, contains('startOfDay.toUtc().toIso8601String()'));
    expect(fetch, contains('endOfDay.toUtc().toIso8601String()'));
  });

  test('local two-day calendar boundaries stay on midnight', () {
    for (final date in [
      DateTime(2026, 4, 23),
      DateTime(2026, 10, 29),
      DateTime(2026, 11, 12),
    ]) {
      final end = DateTime(date.year, date.month, date.day + 2);
      expect(end.hour, 0);
      expect(end.minute, 0);
      expect(end.day, DateTime(date.year, date.month, date.day + 2).day);
    }
  });
}
