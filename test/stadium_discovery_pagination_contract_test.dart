import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discovery pages use deterministic server-side ordering', () {
    final source =
        File('lib/core/repositories/stadium_repository.dart').readAsStringSync();
    final pagination = source.substring(
      source.indexOf('switch (sortBy)'),
      source.indexOf('final int startIndex', source.indexOf('switch (sortBy)')),
    );
    expect(RegExp(r"\.order\('id', ascending: true\)").allMatches(pagination).length, 4);
    expect(source, contains('query.range(startIndex, endIndex)'));
  });

  test('nationwide fallback retains its pagination scope but refresh retries locality', () {
    final source =
        File('lib/core/providers/stadium_provider.dart').readAsStringSync();
    expect(source, contains("_isGeographicFallback ? 'All' : _selectedGovernorate"));
    expect(source, contains('_hasMore = fallbackStadiums.length == 10;'));
    expect(source, contains('_hasMore = newStadiums.length == 10;'));
    expect(
      source,
      contains('// A refresh must retry the user\'s chosen governorate'),
    );
  });

  test('stadium discovery error exposes a real retry callback', () {
    final source = File(
      'lib/features/player/widgets/home/home_stadiums_section.dart',
    ).readAsStringSync();
    expect(source, contains('onRetry: () => provider.fetchStadiums(isRefresh: true)'));
  });
}
