import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('governorate and server-side filters publish empty/loading state', () {
    final source = File('lib/core/providers/stadium_provider.dart')
        .readAsStringSync();
    for (final section in ['applyGovernorateFilter(', 'applyFilters(']) {
      final start = source.indexOf('void $section');
      expect(start, greaterThanOrEqualTo(0));
      final end = source.indexOf('fetchStadiums', start);
      final body = source.substring(start, end);
      expect(body, contains('_stadiums = [];'));
      expect(body, contains('_errorMessage = null;'));
      expect(body, contains('notifyListeners();'));
    }
  });

  test('filtered fetch diagnostics redact transport errors', () {
    final source = File('lib/core/providers/stadium_provider.dart')
        .readAsStringSync();
    expect(source, contains('Filtered stadium fetch failed (details redacted)'));
    expect(source,
        isNot(contains("VSPLogger.e('Failed to fetch filtered stadiums', e)")));
  });
}
