import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('challenge and matchup results require explicit server success', () {
    final source = File(
      'lib/core/repositories/booking/booking_reconciliation_service.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<bool> submitMatchResult(');
    final end = source.indexOf('Future<void> _submitRating(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains("'record_matchup_result_atomic'"));
    expect(method, contains("'submit_challenge_result_atomic'"));
    expect(method, contains("result is! Map || result['success'] != true"));
    expect(method, contains("result is Map && result['error'] == 'RESULT_DISPUTED'"));
    expect(method, contains('INVALID_RESULT_RESPONSE'));
  });
}
