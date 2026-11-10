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
    final repository = File(
      'lib/core/repositories/match_repository.dart',
    ).readAsStringSync();

    expect(provider, contains('final Set<String> _joiningMatchKeys = {};'));
    expect(provider, contains('final Set<String> _leavingMatchKeys = {};'));
    expect(provider, contains('if (!_joiningMatchKeys.add(actionKey)) return false;'));
    expect(provider, contains('if (!_leavingMatchKeys.add(actionKey)) return false;'));
    expect(provider, contains('_joiningMatchKeys.remove(actionKey)'));
    expect(provider, contains('_leavingMatchKeys.remove(actionKey)'));
    expect(categorizer, contains("return 'match_action_failed';"));
    expect(categorizer, isNot(contains("return errorStr.replaceAll('Exception: ', '');")));

    final joinStart = repository.indexOf('Future<bool> joinPublicMatch(');
    final leaveStart = repository.indexOf('Future<bool> leavePublicMatch(');
    final removeStart = repository.indexOf(
      'Future<bool> removeParticipantFromPublicMatch(',
      leaveStart,
    );
    final joinSource = repository.substring(joinStart, leaveStart);
    final leaveSource = repository.substring(leaveStart, removeStart);
    expect(
      joinSource.indexOf("rpc('request_join_public_match'"),
      lessThan(joinSource.indexOf("from('booking_public_feed')")),
    );
    expect(joinSource, contains('notification enrichment unavailable'));
    expect(leaveSource, isNot(contains("from('booking_public_feed')")));
  });
}
