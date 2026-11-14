import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard and challenge creation validate before calling RPC', () {
    final source = File(
      'lib/core/repositories/booking/booking_creation_coordinator.dart',
    ).readAsStringSync();

    final validation = source.indexOf('final validationErrors = draft.validate()');
    final userValidation = source.indexOf('if (userId.trim().isEmpty)');
    final challengeRpc = source.indexOf("_supabase.rpc('create_challenge_booking_atomic'");
    final standardRpc = source.indexOf("_supabase.rpc('create_booking_atomic'");
    expect(validation, greaterThanOrEqualTo(0));
    expect(userValidation, greaterThan(validation));
    expect(challengeRpc, greaterThan(userValidation));
    expect(standardRpc, greaterThan(userValidation));
  });

  test('both booking creation RPCs receive an idempotency key', () {
    final source = File(
      'lib/core/repositories/booking/booking_creation_coordinator.dart',
    ).readAsStringSync();
    final matches = RegExp("'p_idempotency_key': draft.idempotencyKey")
        .allMatches(source);
    expect(matches.length, 2);
  });

  test('the current SQL checks overlap after a stadium transaction lock', () {
    final sql = File(
      'supabase/migrations/20261106010000_recheck_booking_idempotency_after_lock.sql',
    ).readAsStringSync();
    final lock = sql.indexOf('pg_advisory_xact_lock(hashtextextended(p_stadium_id,0))');
    final overlap = sql.indexOf('p_start_time<end_time AND p_end_time>start_time');
    expect(lock, greaterThanOrEqualTo(0));
    expect(overlap, greaterThan(lock));
    expect(sql, contains('SLOT_LOCKED_OR_TAKEN'));
  });
}
