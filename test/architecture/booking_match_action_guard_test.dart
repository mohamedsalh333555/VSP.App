import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public match join and leave actions are single flight and sanitized', () {
    final provider = File(
      'lib/core/providers/booking_provider.dart',
    ).readAsStringSync();
    final categorizer = File(
      'lib/core/providers/booking/booking_categorization_service.dart',
    ).readAsStringSync();

    expect(provider, contains('final Set<String> _joiningMatchKeys = {};'));
    expect(provider, contains('final Set<String> _leavingMatchKeys = {};'));
    expect(provider, contains('if (!_joiningMatchKeys.add(actionKey)) return false;'));
    expect(provider, contains('if (!_leavingMatchKeys.add(actionKey)) return false;'));
    expect(provider, contains('_joiningMatchKeys.remove(actionKey)'));
    expect(provider, contains('_leavingMatchKeys.remove(actionKey)'));
    expect(categorizer, contains("return 'match_action_failed';"));
    expect(categorizer, isNot(contains("return errorStr.replaceAll('Exception: ', '');")));
  });
}
