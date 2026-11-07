import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking result coordinator rejects unrelated teams before RPC', () {
    final source = File(
      'lib/core/repositories/booking/booking_reconciliation_service.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<bool> submitMatchResult(');
    final end = source.indexOf('Future<void> _submitRatingBestEffort(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains('teamId != booking.playerTeamId'));
    expect(method, contains('teamId != booking.opponentTeamId'));
    expect(method.indexOf('teamId != booking.playerTeamId'),
        lessThan(method.indexOf("'record_matchup_result_atomic'")));
    expect(method.indexOf('teamId != booking.playerTeamId'),
        lessThan(method.indexOf("'submit_challenge_result_atomic'")));
  });
}
