import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redacted opponent outcome still offers independent submission', () {
    final source = File(
      'lib/features/player/widgets/user_bookings/challenge_result_actions.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'if (booking.matchResultStatus == MatchResultStatus.waitingOpponent)',
      source.indexOf('Widget build(BuildContext context) {'),
    );
    final end = source.indexOf(
      'if (booking.matchResultStatus == MatchResultStatus.confirmed)',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final panel = source.substring(start, end);
    expect(panel, contains('booking.resultSubmittedByTeamId?.isNotEmpty == true'));
    expect(panel, isNot(contains('booking.pendingOutcome')));
    expect(panel, contains('Syncing result status'));
    expect(
      panel,
      contains('Opponent submitted. Record your result independently.'),
    );
    expect(panel, contains('_openResultModal(context, currentTeamId)'));
  });
}
