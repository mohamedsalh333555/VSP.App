import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('team profile flags partially loaded member profiles', () {
    final source = File(
      'lib/features/player/screens/team_profile_screen.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('_hasMemberLoadError = members.length < memberIds.length;'),
    );
    expect(source, contains('getUsersByIdsStrict(memberIds)'));
    expect(source, contains('_hasMemberLoadError = false;'));
  });
}
