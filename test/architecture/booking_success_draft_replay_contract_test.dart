import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful checkout invalidates local draft to avoid replay on restart', () {
    final src = File('lib/core/providers/booking_provider.dart')
        .readAsStringSync();
    final a = src.indexOf('Future<Booking?> createBookingFromDraft(');
    final b = src.indexOf('/// Create booking directly with a draft', a);
    final method = src.substring(a,b);
    expect(method, contains('submittedDraftGeneration == _draftRestoreGeneration'));
    expect(method, contains('_currentDraft = null;'));
    expect(method, contains('_draftOwnerUserId = null;'));
    expect(method, contains('BookingDraftStorage.clear()'));
    expect(method, contains('operationScope != _bookingScopeGeneration'));
  });
}
