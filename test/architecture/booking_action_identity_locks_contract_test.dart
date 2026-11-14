import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in-flight booking and team action locks reset only on identity change',
      () {
    final source = File('lib/core/providers/booking_provider.dart')
        .readAsStringSync();
    final start = source.indexOf('void _resetActionLocksForIdentityChange()');
    final end = source.indexOf('}', start);
    final reset = source.substring(start, end);
    for (final lock in <String>[
      '_cancellingIds', '_updatingPaymentIds', '_rescheduleRequestIds',
      '_rescheduleResponseIds', '_joiningMatchKeys', '_leavingMatchKeys',
    ]) {
      expect(reset, contains('$lock.clear();'), reason: lock);
    }
    expect(source.split('_resetActionLocksForIdentityChange();').length - 1, 2);
    for (final lock in <String>[
      '_cancellingIds', '_updatingPaymentIds', '_rescheduleRequestIds',
      '_rescheduleResponseIds', '_joiningMatchKeys', '_leavingMatchKeys',
    ]) {
      expect(source, contains('$lock.remove('));
    }
    expect(source, contains('actionIdentity == _actionIdentityGeneration'));
  });
}
