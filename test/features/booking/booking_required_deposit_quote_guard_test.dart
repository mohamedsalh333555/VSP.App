import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_price_snapshot_guard.dart';

void main() {
  bool valid(double total, double deposit, {bool required = true}) =>
      BookingPriceSnapshotGuard.isValidDepositQuote(
        bookingTotal: total, deposit: deposit, needsDeposit: required,
      );

  test('valid partial and full required deposits do not exceed booking total', () {
    expect(valid(100, 25), isTrue);
    expect(valid(100, 100), isTrue);
    expect(valid(50.25, 20.10), isTrue);
    expect(valid(100, 0, required: false), isTrue);
    expect(valid(100, 50, required: false), isTrue);
  });

  test('rejects over-collection, required zero and negative deposit', () {
    expect(valid(100, 100.01), isFalse);
    expect(valid(50, 100), isFalse);
    expect(valid(100, 0), isFalse);
    expect(valid(100, -1), isFalse);
    expect(valid(100, -1, required: false), isFalse);
  });

  test('rejects non-finite, zero and negative booking totals', () {
    for (final total in [
      0.0, -1.0, double.nan, double.infinity, double.negativeInfinity,
    ]) {
      expect(valid(total, 10), isFalse, reason: 'invalid total');
    }
    for (final deposit in [
      double.nan, double.infinity, double.negativeInfinity,
    ]) {
      expect(valid(100, deposit), isFalse, reason: 'invalid deposit');
    }
  });

  test('does not reject a microscopic floating point reconstruction delta', () {
    expect(valid(99.999999999, 100), isTrue);
    expect(valid(99.99, 100), isFalse);
  });

  test('the live confirmation preflight compares the server quote and deposit', () {
    final guard = File(
      'lib/features/player/widgets/booking/booking_price_snapshot_guard.dart',
    ).readAsStringSync();
    final handler = File(
      'lib/features/player/widgets/booking/booking_confirmation_handler.dart',
    ).readAsStringSync();

    expect(guard, contains('isValidDepositQuote('));
    expect(guard, contains('bookingTotal: serverQuote'));
    expect(guard, contains('deposit: latest.depositAmount'));
    expect(guard, contains('needsDeposit: latest.needsDeposit'));
    expect(handler, contains('getStadiumByIdStrict(stadium.id)'));
    expect(handler, contains('BookingPriceSnapshotGuard.matches('));
    expect(handler, contains('displayedTotal: totalPrice'));
    expect(handler, contains('Reopen the venue to review the price before confirming.'));
  });
}
