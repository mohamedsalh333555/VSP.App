import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking detail lookup cannot return an old account result', () {
    final source = File('lib/core/providers/booking_provider.dart')
        .readAsStringSync();
    final begin = source.indexOf('Future<Booking?> getBookingById(');
    final end = source.indexOf('/// Fetch public matches', begin);
    expect(begin, greaterThanOrEqualTo(0));
    expect(end, greaterThan(begin));
    final method = source.substring(begin, end);
    expect(method, contains('final actionIdentity = _actionIdentityGeneration;'));
    expect(method, contains('actionIdentity == _actionIdentityGeneration ? booking : null'));
  });
}
