import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public feed first load, retry and refresh are transparently scoped', () {
    final provider = File('lib/core/providers/booking_provider.dart')
        .readAsStringSync();
    final start = provider.indexOf('Future<void> fetchPublicMatches(');
    final end = provider.indexOf('/// Join a public match', start);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final flow = provider.substring(start, end);
    expect(flow, contains('_isLoadingPublicMatches = true;'));
    expect(flow, contains('_publicMatches = [];'));
    expect(flow, contains('_errorMessage = null;'));
    expect(flow, contains('operationScope != _bookingScopeGeneration'));
    expect(flow, contains('تعذر تحميل المباريات حالياً.'));
    final service = File(
      'lib/core/providers/booking/booking_match_coordinator.dart',
    ).readAsStringSync();
    expect(service, contains('stream.first.timeout(const Duration(seconds: 12))'));
  });
}
