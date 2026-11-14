import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('secondary async operations isolate errors and state after account switch', () {
    final source = File('lib/core/providers/booking_provider.dart')
        .readAsStringSync();
    const boundaries = <String, String>{
      'requestReschedule({': '/// Respond to rescheduling request',
      'respondToReschedule({': '/// Request emergency stadium closure',
      'requestEmergencyClosure({': '/// Get a specific booking',
      'fetchPublicMatches({': '/// Join a public match',
      'joinPublicMatch(': '/// Leave a public match',
      'leavePublicMatch(': '/// Submit match result',
      'updateManualBooking({': '/// Get bookings for a specific stadium',
    };
    for (final entry in boundaries.entries) {
      final start = source.indexOf(entry.key);
      final end = source.indexOf(entry.value, start);
      expect(start, greaterThanOrEqualTo(0), reason: entry.key);
      expect(end, greaterThan(start), reason: entry.key);
      final method = source.substring(start, end);
      expect(method, contains('final operationScope = _bookingScopeGeneration;'),
          reason: entry.key);
      expect(method, contains('operationScope == _bookingScopeGeneration'),
          reason: entry.key);
    }
    expect(source, contains('_isLoadingPublicMatches = false;'));
    expect(source, contains('_hasMoreMatches = true;'));
  });
}
