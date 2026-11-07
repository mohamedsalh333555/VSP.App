import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing pending outcome is shown as sync uncertainty, not a recorded score', () {
    final source = File(
      'lib/features/player/widgets/user_bookings/challenge_result_actions.dart',
    ).readAsStringSync();
    final start = source.indexOf('if (booking.matchResultStatus == MatchResultStatus.waitingOpponent)', source.indexOf('Widget build(BuildContext context) {'));
    final end = source.indexOf('if (booking.matchResultStatus == MatchResultStatus.confirmed)', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final panel = source.substring(start, end);
    expect(panel, contains('pending == null'));
    expect(panel, contains('Waiting for the opponent result to sync.'));
    expect(panel, contains('Opponent recorded:'));
    expect(panel.indexOf('pending == null'),
        lessThan(panel.indexOf('Opponent recorded:')));
  });
}
