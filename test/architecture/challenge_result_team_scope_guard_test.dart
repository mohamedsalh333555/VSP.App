import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('result submission controls are scoped to the participating teams', () {
    final source = File(
      'lib/features/player/widgets/user_bookings/challenge_result_actions.dart',
    ).readAsStringSync();
    final start = source.indexOf('Widget build(BuildContext context) {');
    expect(start, greaterThanOrEqualTo(0));
    final build = source.substring(start);
    expect(build, contains('currentTeamId != booking.playerTeamId'));
    expect(build, contains('currentTeamId != booking.opponentTeamId'));
    expect(build.indexOf('currentTeamId != booking.playerTeamId'),
        lessThan(build.indexOf('_openResultModal(context, currentTeamId)')));
  });
}
