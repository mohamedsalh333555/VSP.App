import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20261113143000_fix_expired_stadium_maintenance_booking_guard.sql',
  ).readAsStringSync();

  final contract = File(
    'supabase/tests/booking_operating_maintenance_guard_contract.sql',
  ).readAsStringSync();

  test('maintenance_until means end of an active emergency closure', () {
    expect(migration, contains('and p_maintenance_until > now()'));
    expect(migration, contains('and p_start_time < p_maintenance_until'));
    expect(migration, isNot(contains('p_end_time > p_maintenance_until')));
    expect(migration, contains('stable'));
    expect(migration, isNot(contains('immutable')));
  });

  test('maintenance remediation preserves operating-hours enforcement', () {
    expect(migration, contains("timezone('Africa/Cairo', p_start_time)"));
    expect(migration, contains('v_local_end > v_close_ts'));
    expect(migration, contains('v_local_start < v_break_end_ts'));
    expect(migration, contains('v_local_end > v_break_start_ts'));
    expect(migration, contains('p_start_time is null'));
  });

  test('SQL contracts cover active and expired closures and boundaries', () {
    for (final scenario in <String>[
      'normal in-hours booking',
      'expired maintenance marker',
      'active closure',
      'start exactly at closure end',
      'slot starting after closure end',
      'partial overlap with closure',
      'split-shift break overlap',
      'valid overnight opening',
      'after-hours overnight slot',
      'zero-length booking',
      'null booking start',
    ]) {
      expect(contract, contains(scenario), reason: 'Missing SQL case: $scenario');
    }
  });
}
