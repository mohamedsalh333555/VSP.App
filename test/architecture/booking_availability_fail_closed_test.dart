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
    expect(source, contains('List<Booking>? lastVerified;'));
    expect(source, contains('if (lastVerified == null)'));
  });
}
