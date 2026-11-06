import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('challenge replay is rechecked under stadium lock', () {
    final migration = File(
      'supabase/migrations/'
      '20261106093000_recheck_challenge_idempotency_after_lock.sql',
    ).readAsStringSync();

    expect(migration, contains('pg_advisory_xact_lock'));
    expect(migration, contains('Recheck after serialization:'));
    expect(migration, contains('v_existing_user_id IS DISTINCT FROM v_caller'));
    expect(migration, contains('IDEMPOTENCY_KEY_COLLISION'));
    expect(migration, contains('idempotent'));
    expect(migration, contains('RAISE EXCEPTION'));
    expect(
      migration.indexOf('Recheck after serialization:'),
      greaterThan(migration.indexOf('v_anchor text')),
    );
  });
}
