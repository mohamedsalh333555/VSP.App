import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner CRUD callbacks must guard scope before modifying new session state', () {
    final source = File('lib/core/providers/stadium_provider.dart')
        .readAsStringSync();
    const bounds = <String, String>{
      'Future<Stadium?> getStadiumById(': '// Add stadium (Owner)',
      'Future<String?> addStadium(': '// Update stadium',
      'Future<bool> updateStadium(': 'List<Stadium> filterByLocation(',
      'Future<bool> deleteStadium(': '@override\n',
    };
    for (final entry in bounds.entries) {
      final from = source.indexOf(entry.key);
      final to = source.indexOf(entry.value, from + entry.key.length);
      expect(from, greaterThanOrEqualTo(0), reason: entry.key);
      expect(to, greaterThan(from), reason: entry.key);
      final method = source.substring(from, to);
      expect(method, contains('final operationScope = _scopeGeneration;'));
      expect(method, contains('operationScope != _scopeGeneration'));
    }
  });
}
