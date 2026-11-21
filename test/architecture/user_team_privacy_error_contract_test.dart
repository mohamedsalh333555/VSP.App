import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identity, team and opponent diagnostics do not expose raw exceptions',
      () {
    for (final path in <String>[
      'lib/core/repositories/user_repository.dart',
      'lib/core/repositories/team_repository.dart',
      'lib/core/repositories/team/team_opponent_service.dart',
    ]) {
      final src = File(path).readAsStringSync();
      final logLines = src.split('\n').where((line) =>
          line.contains('VSPLogger.') || line.contains('debugPrint(')).toList();
      for (final line in logLines) {
        expect(line, isNot(contains(r'$userId')), reason: '$path: $line');
        expect(line, isNot(contains(r'$uid')), reason: '$path: $line');
        expect(line, isNot(contains(r'$error')), reason: '$path: $line');
        expect(line, isNot(contains(r'$e')), reason: '$path: $line');
      }
    }
  });

  test('challenge code failures return safe codes, never raw RPC exceptions',
      () {
    final src = File('lib/core/repositories/team_repository.dart')
        .readAsStringSync();
    expect(src, contains("'CHALLENGE_CODE_UNAVAILABLE'"));
    expect(src, contains("'CHALLENGE_LOOKUP_UNAVAILABLE'"));
    expect(src, isNot(contains("'error': e.toString()")));
    expect(src, contains("TimeoutException('Team realtime timeout')"));
    expect(src, contains('Error.throwWithStackTrace(error, stack);'));
  });
}
