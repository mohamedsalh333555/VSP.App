import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkout draft persistence and restoration require a matching identity',
      () {
    final storage = File(
      'lib/core/providers/booking/booking_draft_storage.dart',
    ).readAsStringSync();
    final provider = File(
      'lib/core/providers/booking_provider.dart',
    ).readAsStringSync();

    expect(storage, contains("'account_id': ownerUserId"));
    expect(storage, contains('savedAccount != scope'));
    expect(storage, contains('body is! Map<String, dynamic>'));
    expect(storage, contains('await prefs.remove(_draftKey);'));
    expect(provider, contains('_restoreDraft(userId: userId)'));
    expect(provider, contains('scopeGeneration != _bookingScopeGeneration'));
    expect(provider, contains('unawaited(BookingDraftStorage.clear())'));
  });
}
