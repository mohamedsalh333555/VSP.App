import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('membership stream does not turn network errors into empty teams', () {
    final source = File(
      'lib/core/repositories/team/team_roster_coordinator.dart',
    ).readAsStringSync();
    final start = source.indexOf('Stream<List<Map<String, dynamic>>> streamUserMembership(');
    expect(start, greaterThanOrEqualTo(0));
    final method = source.substring(start);
    expect(method, contains(".stream(primaryKey: ['team_id', 'user_id'])"));
    expect(method, contains('.timeout(const Duration(seconds: 10))'));
    expect(method, isNot(contains('onTimeout: (sink) => sink.add([])')));
    expect(method, isNot(contains('.handleError(')));
  });
}
