import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated clients cannot directly write team memberships', () {
    final sql = File(
      'supabase/migrations/20261106180000_lock_team_member_direct_writes.sql',
    ).readAsStringSync();
    expect(sql, contains('REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER'));
    expect(sql, contains('ON TABLE public.team_members FROM anon, authenticated'));
    expect(sql, contains("cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')"));
    expect(sql, contains("IF p.cmd <> 'ALL' THEN"));
  });
}
