import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refund, cancellation and notification diagnostics hide identifiers and transport errors', () {
    final source = File(
      'lib/core/repositories/booking/booking_cancellation_coordinator.dart',
    ).readAsStringSync();
    final logLines = source.split('\n').where((line) =>
        line.contains('VSPLogger.') || line.contains('debugPrint(')).toList();
    expect(logLines, hasLength(greaterThanOrEqualTo(7)));
    for (final log in logLines) {
      expect(log, isNot(contains(r'$bookingId')), reason: log);
      expect(log, isNot(contains(r'$fnErr')), reason: log);
      expect(log, isNot(contains(r'$e')), reason: log);
      expect(log, isNot(contains("VSPLogger.e('Owner manual booking cancellation RPC failed', e)")));
    }
    // Structured business-code translation remains available to the user,
    // but a raw server exception is never written into diagnostics.
    expect(source, contains('sanitizeCancellationError(e)'));
    expect(source, contains('Refund edge function unavailable; using atomic fallback'));
  });
}
