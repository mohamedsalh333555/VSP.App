import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner Realtime data publishes updates after initial load', () {
    final provider = File('lib/core/providers/stadium_provider.dart')
        .readAsStringSync();
    final start = provider.indexOf('void listenToOwnerStadiums(');
    final end = provider.indexOf('// Get stadium by ID', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final scope = provider.substring(start, end);
    expect(scope, contains('_stadiums = data;'));
    expect(scope, contains('_isLoading = false;'));
    expect(scope, contains('notifyListeners();'));
    expect(scope, contains("_setError('owner_stadium_sync_failed')"));
    expect(scope, isNot(contains('error.toString()')));
    expect(scope, contains('ownerGeneration != _scopeGeneration'));
  });

  test('owner dashboard distinguishes loading and failures from empty data', () {
    final screen = File('lib/features/owner/screens/owner_dashboard_screen.dart')
        .readAsStringSync();
    expect(screen, contains('stadiumProvider.errorMessage != null'));
    expect(screen, contains('stadiums.isEmpty && stadiumProvider.isLoading'));
    expect(screen, contains('_buildOwnerStadiumSyncWarning('));
    expect(screen, contains('forceRefresh: true'));
  });
}
