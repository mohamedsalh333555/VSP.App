import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('team creation enrolls captain only and invites other players', () {
    final source = File('lib/core/repositories/team_repository.dart').readAsStringSync();
    final start = source.indexOf('Future<String?> createTeam(');
    final end = source.indexOf('Future<Team?> getTeam(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final create = source.substring(start, end);
    expect(create, contains("'create_team_with_consent'"));
    expect(create, contains("'p_member_uids': [captainId]"));
    expect(create, contains('await inviteTeamMember(teamId, userId)'));
    expect(create, isNot(contains("'create_team_atomic'")));
  });

  test('legacy direct membership RPC is blocked server side', () {
    final migration = File(
      'supabase/migrations/20261106173000_enforce_team_member_consent.sql',
    ).readAsStringSync();
    expect(migration, contains('CREATE OR REPLACE FUNCTION public.add_team_member_atomic'));
    expect(migration, contains("'TEAM_INVITATION_REQUIRED'"));
    expect(migration, contains('cardinality(p_member_uids) <> 1'));
    expect(migration, contains('REVOKE ALL ON FUNCTION public.create_team_atomic'));
    expect(migration, contains('GRANT EXECUTE ON FUNCTION public.create_team_with_consent'));
  });
}
