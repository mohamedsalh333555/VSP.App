import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking safety reads distinguish missing pitches from backend failure',
      () {
    final repo = File('lib/core/repositories/stadium_repository.dart')
        .readAsStringSync();
    final provider = File('lib/core/providers/stadium_provider.dart')
        .readAsStringSync();
    final strictStart = repo.indexOf('Future<Stadium?> getStadiumByIdStrict(');
    final strictEnd = repo.indexOf('// Get raw stadium data', strictStart);
    expect(strictStart, greaterThan(0));
    expect(strictEnd, greaterThan(strictStart));
    final strict = repo.substring(strictStart, strictEnd);
    expect(strict, contains('.eq(\'is_verified\', true)'));
    expect(strict, contains('.eq(\'is_blocked\', false)'));
    expect(strict, isNot(contains('catch (')));
    expect(provider, contains('_databaseService.getStadiumByIdStrict(stadiumId)'));
    expect(provider, contains("_setError('stadium_fetch_failed')"));
  });
}
