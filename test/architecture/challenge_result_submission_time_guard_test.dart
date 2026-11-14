import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('result action is not offered before match end', () {
    final source = File(
      'lib/features/player/widgets/user_bookings/challenge_result_actions.dart',
    ).readAsStringSync();
    final start = source.indexOf('Widget build(BuildContext context) {');
    final noResult = source.indexOf(
      'if (booking.matchResultStatus == MatchResultStatus.noResult)', start);
    final waiting = source.indexOf(
      'if (booking.matchResultStatus == MatchResultStatus.waitingOpponent)', noResult);
    expect(noResult, greaterThan(start));
    expect(waiting, greaterThan(noResult));
    final branch = source.substring(noResult, waiting);
    expect(branch, contains('booking.endTime.isAfter(VSPTimeService.now)'));
    expect(branch, contains('return const SizedBox.shrink();'));
    expect(branch.indexOf('booking.endTime.isAfter(VSPTimeService.now)'),
        lessThan(branch.indexOf('_openResultModal(context, currentTeamId)')));
  });
  test('pending opponent action is also hidden until match ends', () {
    final source = File(
      'lib/features/player/widgets/user_bookings/challenge_result_actions.dart',
    ).readAsStringSync();
    final start = source.indexOf('Widget build(BuildContext context) {');
    final pending = source.indexOf(
      'if (booking.matchResultStatus == MatchResultStatus.waitingOpponent)', start);
    final confirmed = source.indexOf(
      'if (booking.matchResultStatus == MatchResultStatus.confirmed)', pending);
    expect(pending, greaterThan(start));
    expect(confirmed, greaterThan(pending));
    final branch = source.substring(pending, confirmed);
    expect(branch, contains('hasSubmissionDetails &&'));
    expect(branch, contains('!submittedByMe &&'));
    expect(branch, contains('!booking.endTime.isAfter(VSPTimeService.now)'));
    expect(branch.indexOf('hasSubmissionDetails &&'),
        lessThan(branch.indexOf('_openResultModal(context, currentTeamId)')));
  });

}
