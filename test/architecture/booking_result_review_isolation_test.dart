import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('review failures cannot reverse a successful match result', () {
    final source = File(
      'lib/core/repositories/booking/booking_reconciliation_service.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<bool> submitMatchResult(');
    final end = source.indexOf('Future<void> _submitRatingBestEffort(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final submission = source.substring(start, end);
    expect(submission, contains("result['success'] != true"));
    expect(submission, contains("result['error'] == 'RESULT_DISPUTED'"));
    expect('await _submitRatingBestEffort('.allMatches(submission).length, 2);
    expect(submission, isNot(contains('await _submitRating(')));

    final helper = source.substring(end);
    expect(helper, contains('catch (error)'));
    expect(helper, contains("result is! Map || result['success'] != true"));
    expect(helper, contains('INVALID_REVIEW_RESPONSE'));
  });
}
