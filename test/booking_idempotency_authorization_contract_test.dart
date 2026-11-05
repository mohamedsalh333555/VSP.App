import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SEC-06: booking idempotency replay is scoped to the original request', () {
    final sql = File(
      'supabase/migrations/20261105014000_harden_booking_idempotency_lookup.sql',
    ).readAsStringSync();

    expect(sql, contains('CREATE OR REPLACE FUNCTION public.create_booking_atomic'));
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains('v_caller::text<>p_user_id'));
    expect(sql, contains('AND user_id::text=p_user_id'));
    expect(sql, contains('AND stadium_id::text=p_stadium_id'));
    expect(sql, contains('AND start_time=p_start_time AND end_time=p_end_time'));
    expect(sql, contains("'IDEMPOTENCY_KEY_CONFLICT'"));

    // A replay lookup must never be keyed solely by a caller-supplied token.
    final replay = RegExp(
      r'SELECT id,status INTO v_existing_id,v_existing_status([\\s\\S]*?)IF FOUND',
    ).firstMatch(sql);
    expect(replay, isNotNull);
    final lookup = replay!.group(1)!;
    expect(lookup, contains('user_id::text=p_user_id'));
    expect(lookup, contains('stadium_id::text=p_stadium_id'));
  });
}
