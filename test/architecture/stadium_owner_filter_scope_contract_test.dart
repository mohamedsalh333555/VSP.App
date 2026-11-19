import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner stream data cannot be overwritten by player filters', () {
    final source = File('lib/core/providers/stadium_provider.dart')
        .readAsStringSync();
    for (final name in <String>[
      'void toggleQuickFilter(',
      'void applyGovernorateFilter(',
      'void applyFilters(',
      'Future<void> clearFilters()',
    ]) {
      final start = source.indexOf(name);
      expect(start, greaterThanOrEqualTo(0), reason: name);
      expect(source.substring(start, start + 170),
          contains('if (_listeningOwnerId != null) return;'),
          reason: name);
    }
  });
}
