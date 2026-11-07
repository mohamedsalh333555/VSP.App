import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirmed challenge without outcome is not reported as a loss', () {
    final source = File(
      'lib/features/player/widgets/user_bookings/challenge_result_actions.dart',
    ).readAsStringSync();
    final start = source.indexOf('if (booking.matchResultStatus == MatchResultStatus.confirmed)');
    final end = source.indexOf('if (booking.matchResultStatus == MatchResultStatus.waitingOpponent)', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final confirmed = source.substring(start, end);
    expect(confirmed, contains('if (outcome == null)'));
    expect(confirmed, contains('Result unavailable'));
    expect(confirmed.indexOf('if (outcome == null)'),
        lessThan(confirmed.indexOf('final won')));
  });
  test('confirmed result panel does not claim standings update without outcome', () {
    final source = File(
      'lib/features/player/widgets/user_bookings/challenge_result_actions.dart',
    ).readAsStringSync();
    final start = source.indexOf('Widget build(BuildContext context) {');
    final confirmed = source.indexOf(
      'if (booking.matchResultStatus == MatchResultStatus.confirmed)', start);
    expect(confirmed, greaterThan(start));
    final panel = source.substring(confirmed);
    expect(panel, contains('if (booking.finalOutcome == null)'));
    expect(panel, contains('Result currently unavailable'));
    expect(panel.indexOf('if (booking.finalOutcome == null)'),
        lessThan(panel.indexOf('Result confirmed and team standings updated.')));
  });

}
