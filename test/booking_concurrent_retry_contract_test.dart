import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Booking retries recheck scoped idempotency after stadium lock', () {
    final sql = File(
      'supabase/migrations/20261106010000_recheck_booking_idempotency_after_lock.sql',
    ).readAsStringSync();
    final lock = sql.indexOf('PERFORM pg_advisory_xact_lock(');
    final postLock = sql.substring(lock);
    final recheck = postLock.indexOf('SELECT id,status INTO v_existing_id,v_existing_status');
    final stadiumRead = postLock.indexOf('SELECT * INTO v_stadium');
    expect(lock, greaterThan(0));
    expect(recheck, greaterThan(0));
    expect(stadiumRead, greaterThan(recheck));
    final replay = postLock.substring(recheck, stadiumRead);
    expect(replay, contains('user_id::text=p_user_id'));
    expect(replay, contains('stadium_id::text=p_stadium_id'));
    expect(replay, contains('start_time=p_start_time AND end_time=p_end_time'));
    expect(replay, contains("'IDEMPOTENCY_KEY_CONFLICT'"));
    expect(replay, contains("'idempotent',true"));
  });
}
