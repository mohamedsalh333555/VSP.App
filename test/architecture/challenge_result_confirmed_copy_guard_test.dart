import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirmed result does not promise unverified standings refresh', () {
    final source = File(
      'lib/features/player/widgets/user_bookings/challenge_result_actions.dart',
    ).readAsStringSync();
    final start = source.indexOf('Widget build(BuildContext context) {');
    final confirmed = source.indexOf(
      'if (booking.matchResultStatus == MatchResultStatus.confirmed)', start);
    expect(confirmed, greaterThan(start));
    final branch = source.substring(confirmed);
    expect(branch, contains('تم اعتماد النتيجة. يمكنك مراجعة ترتيب الفرق.'));
    expect(branch, contains('Result confirmed. You can check the team standings.'));
    expect(branch, isNot(contains('team standings updated')));
    expect(branch, contains('navigateToTeamsStandings(context)'));
  });
}
