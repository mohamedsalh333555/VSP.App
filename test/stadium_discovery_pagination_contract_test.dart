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

  test('exhausted discovery pages never issue redundant fetches', () {
    final source =
        File('lib/core/providers/stadium_provider.dart').readAsStringSync();
    expect(
      RegExp(r'if \(!isRefresh && \(!_hasMore \|\| _isLoading \|\| _isLoadingMore\)\) return;')
          .allMatches(source)
          .length,
      2,
    );
  });

  test('nearby discovery stops at the RPC 100-row ceiling', () {
    final source =
        File('lib/core/providers/stadium_provider.dart').readAsStringSync();
    expect(
      source,
      contains('limit < 100 && nearbyStadiums.length >= limit'),
    );
  });

  test('explicit governorate queries bypass unnecessary GPS checks', () {
    final source =
        File('lib/core/providers/stadium_provider.dart').readAsStringSync();
    final discovery = source.substring(
      source.indexOf('Future<void> fetchStadiums({'),
      source.indexOf('Future<void> fetchStadiumsWithParams({'),
    );
    final gpsGuard = discovery.indexOf(
      'if (_selectedGovernorate == null || _selectedGovernorate!.isEmpty) {',
    );
    final gpsServiceCheck = discovery.indexOf('Geolocator.isLocationServiceEnabled()');
    expect(gpsGuard, greaterThanOrEqualTo(0));
    expect(gpsServiceCheck, greaterThan(gpsGuard));
  });

  test('nearby pages reuse a GPS snapshot until refresh', () {
    final source =
        File('lib/core/providers/stadium_provider.dart').readAsStringSync();
    expect(source, contains('Position? _discoveryPagePosition;'));
    expect(source, contains('Position? userPosition = _discoveryPagePosition;'));
    expect(source, contains('userPosition == null) {'));
    expect(source, contains('_discoveryPagePosition = userPosition;'));
    expect(source, contains('_discoveryPagePosition = null;'));
  });

  test('superseded GPS requests never start a stadium query', () {
    final source =
        File('lib/core/providers/stadium_provider.dart').readAsStringSync();
    final discovery = source.substring(
      source.indexOf('Future<void> fetchStadiums({'),
      source.indexOf('Future<void> fetchStadiumsWithParams({'),
    );
    final guard = discovery.indexOf(
      '// Do not send a superseded discovery query to Supabase.',
    );
    final nearby = discovery.indexOf('_databaseService.fetchNearbyStadiums(');
    final paginated = discovery.indexOf('_databaseService.getStadiumsPaginated(');
    expect(guard, greaterThan(0));
    expect(nearby, greaterThan(guard));
    expect(paginated, greaterThan(guard));
  });

  test('stadium discovery error exposes a real retry callback', () {
    final source = File(
      'lib/features/player/widgets/home/home_stadiums_section.dart',
    ).readAsStringSync();
    expect(source, contains('onRetry: () => provider.fetchStadiums(isRefresh: true)'));
  });
}
