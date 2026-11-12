import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking confirmation checks the authoritative RPC, not a cached stream', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_confirmation_handler.dart',
    ).readAsStringSync();

    final checkStart = source.indexOf('// ── Pre-confirmation double-check');
    final checkEnd = source.indexOf('// ── Build the booking draft', checkStart);
    expect(checkStart, greaterThanOrEqualTo(0));
    expect(checkEnd, greaterThan(checkStart));

    final check = source.substring(checkStart, checkEnd);
    expect(check, contains('fetchStadiumBookingsDirectly(stadium.id, selectedDate)'));
    expect(check, contains('.timeout(const Duration(seconds: 10))'));
    expect(check, isNot(contains('.getBookingsForStadium(')));
    expect(check, contains('if (isConflict)'));
    expect(check, contains('Error checking slot availability before booking'));
    expect(check, contains('لم يتم إرسال الحجز'));
  });
}
