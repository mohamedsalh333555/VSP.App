import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acceptance serializes membership limits per player across teams', () {
    final sql = File(
      'supabase/migrations/20261106183000_serialize_team_invitation_acceptance.sql',
    ).readAsStringSync();
    final lock = sql.indexOf('pg_advisory_xact_lock(');
    final teamLock = sql.indexOf('FOR UPDATE;');
    expect(lock, greaterThanOrEqualTo(0));
    expect(teamLock, greaterThan(lock));
    expect(sql, contains('count(*) FROM public.team_members WHERE user_id = auth.uid()'));
    expect(sql, contains('Player reached maximum teams'));
    expect(sql, contains('Invitation belongs to another player'));
    expect(sql, contains('Already a member'));
  });
}
