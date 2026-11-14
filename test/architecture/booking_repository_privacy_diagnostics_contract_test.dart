import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking repositories do not reveal raw transport exceptions and IDs',
      () {
    const sources = <String>[
      'lib/core/repositories/booking/booking_creation_coordinator.dart',
      'lib/core/repositories/booking/booking_query_coordinator.dart',
      'lib/core/repositories/booking/booking_reconciliation_service.dart',
      'lib/core/repositories/booking/booking_schedule_coordinator.dart',
    ];
    for (final path in sources) {
      final src = File(path).readAsStringSync();
      final logs = src.split('\n').where((line) =>
          line.contains('VSPLogger.') || line.contains('debugPrint('));
      for (final log in logs) {
        expect(log, isNot(contains(r'$userId')), reason: '$path: $log');
        expect(log, isNot(contains(r'$bookingId')), reason: '$path: $log');
        expect(log, isNot(contains(r'$error')), reason: '$path: $log');
        expect(log, isNot(contains(r'$e')), reason: '$path: $log');
        expect(log, isNot(contains('VSPLogger.e(\'Error creating booking\', e)')));
      }
    }
  });

  test('emergency closure exceptions never appear in user-facing message', () {
    final source = File(
      'lib/core/repositories/booking/booking_schedule_coordinator.dart',
    ).readAsStringSync();
    expect(source, contains('Emergency closure RPC failed (details redacted)'));
    expect(source, contains('تعذر إرسال طلب الإغلاق الطارئ. حاول مرة أخرى.'));
    expect(source, isNot(contains("'message': e.toString()")));
    // The RPC still determines success and authorized business errors.
    expect(source, contains('requestEmergencyClosure'));
  });
}
