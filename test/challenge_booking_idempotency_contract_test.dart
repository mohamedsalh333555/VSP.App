import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('challenge replay has a caller-owned post-lock recheck', () {
    final migration = File(
      'supabase/migrations/'
      '20261106093000_recheck_challenge_idempotency_after_lock.sql',
    ).readAsStringSync();

    // This migration patches the effective function, not an old full body.
    expect(migration, contains('pg_get_functiondef(p.oid)'));
    expect(migration, contains('pg_get_function_identity_arguments(p.oid)'));
    expect(migration, contains('RAISE EXCEPTION'));

    final patchStart = migration.indexOf('-- Recheck after serialization:');
    final patchEnd = migration.indexOf(r'$patch$;', patchStart);
    expect(patchStart, greaterThanOrEqualTo(0));
    expect(patchEnd, greaterThan(patchStart));
    final patch = migration.substring(patchStart, patchEnd);

    // A collision must never expose another account's booking ID.
    expect(patch, contains('v_existing_user_id IS DISTINCT FROM v_caller'));
    expect(patch, contains('v_caller IS NULL'));
    expect(patch, contains('IDEMPOTENCY_KEY_COLLISION'));
    expect(patch.indexOf('IDEMPOTENCY_KEY_COLLISION'),
        lessThan(patch.indexOf("'booking_id', v_existing_id")));

    // Replay is explicitly re-evaluated after the transaction lock.
    expect(migration, contains('v_anchor ||'));
    expect(migration, contains("E'\\n' || v_patch"));
    expect(migration, contains('pg_advisory_xact_lock'));
    expect(patch, contains("status <> 'cancelled'"));
    expect(patch, contains("'idempotent', true"));
  });
}
