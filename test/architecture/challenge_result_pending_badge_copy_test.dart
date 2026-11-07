import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending badge does not imply that both results were already submitted', () {
    final source = File(
      'lib/features/player/widgets/user_bookings/challenge_result_actions.dart',
    ).readAsStringSync();
    final start = source.indexOf('static Widget buildChallengeStatusBadge(');
    final end = source.indexOf('static Widget buildStatusBadge(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final badge = source.substring(start, end);
    expect(badge, contains('في انتظار نتيجة الفريق الآخر'));
    expect(badge, contains('جارٍ تحديث حالة النتيجة'));
    expect(badge, contains('Syncing result status'));
    expect(badge, contains('booking.pendingOutcome != null'));
    expect(badge, contains('submittedTeamId.isNotEmpty'));
    expect(badge, contains('submittedTeamId == currentTeamId'));
    expect(badge, contains('الفريق الآخر سجّل نتيجته، سجّل نتيجتك'));
    expect(badge, contains('Opponent submitted; record your result'));
    expect(badge, contains('Waiting for the other team result'));
    expect(badge, isNot(contains('Waiting for matching result')));
  });
}
