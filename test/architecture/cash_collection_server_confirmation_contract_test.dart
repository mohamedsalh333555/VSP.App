import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cash collection only returns success after explicit server confirmation',
      () {
    final repository = File('lib/core/repositories/booking_repository.dart')
        .readAsStringSync();
    final start = repository.indexOf(
      'Future<bool> updatePaymentStatus(String bookingId, bool isPaid) async',
    );
    final end = repository.indexOf(
      'Future<void> autoReconcilePastBookings',
      start,
    );
    final section = repository.substring(start, end);
    expect(section, contains('if (!isPaid) return false;'));
    expect(section, contains("rpcRes['success'] != true"));
    expect(section, contains("rpcRes['already_confirmed'] == true"));
    expect(section, contains('CashCollectionValidation.calculateDue('));
    expect(section, contains("'p_collected_amount': cashDue"));
    expect(section, isNot(contains("rpcRes['message']")));
    expect(section, isNot(contains('debugPrint(\'Error updating payment status via RPC: \$e\')')));
  });
}
