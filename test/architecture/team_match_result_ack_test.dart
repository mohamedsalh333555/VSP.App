import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('team match results require positive atomic RPC confirmation', () {
    final source = File('lib/core/repositories/team_repository.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<void> updateMatchResult(');
    final end = source.indexOf('Future<Set<String>> getUserCaptainTeamIds(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains("'submit_challenge_result_atomic'"));
    expect(method, contains("response is! Map || response['success'] != true"));
    expect(method, contains('response is Map'));
  });
}
