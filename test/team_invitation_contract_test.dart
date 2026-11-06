import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captain picker sends invitation rather than directly adding a member', () {
    final source = File(
      'lib/features/player/widgets/my_team/my_team_controller.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _onPlayerAdded(');
    final end = source.indexOf('// ── Remove member', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains('inviteTeamMember(currentTeam.id, user.uid)'));
    expect(method, isNot(contains('addMemberToTeam(')));
  });

  test('invitation RPCs enforce captain and recipient authority', () {
    final migration = File(
      'supabase/migrations/20261106170000_team_membership_invitations.sql',
    ).readAsStringSync();
    expect(migration, contains('v_captain IS DISTINCT FROM auth.uid()'));
    expect(migration, contains('v_invite.invited_user_id IS DISTINCT FROM auth.uid()'));
    expect(migration, contains('ALTER TABLE public.team_membership_invitations ENABLE ROW LEVEL SECURITY'));
    expect(migration, contains('ON CONFLICT (team_id, user_id) DO NOTHING'));
    expect(migration, contains('GRANT EXECUTE ON FUNCTION public.respond_team_membership_invitation'));
  });
}
