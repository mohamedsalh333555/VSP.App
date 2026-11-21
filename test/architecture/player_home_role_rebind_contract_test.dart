import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('player home resets owner scope before executing discovery filters', () {
    final src = File(
      'lib/features/player/screens/player_home_screen.dart',
    ).readAsStringSync();
    expect(src, contains('stadiumProvider.enterPlayerDiscoveryScope();'));
    expect(
      src.indexOf('stadiumProvider.enterPlayerDiscoveryScope();'),
      lessThan(src.indexOf('stadiumProvider.applyGovernorateFilter(')),
    );
    expect(src, contains('currentUser?.id != currentPlayerId'));
    expect(src, contains('currentUser?.id == userId'));
    expect(src, contains('Captain access verification failed (details redacted)'));
  });
}
