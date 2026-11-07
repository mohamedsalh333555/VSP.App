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
  test('invitation expiry and wrong-recipient guards are enforced by RPC', () {
    final migration = File(
      'supabase/migrations/20261106170000_team_membership_invitations.sql',
    ).readAsStringSync();
    expect(migration, contains("v_invite.expires_at <= now()"));
    expect(migration, contains("v_invite.invited_user_id IS DISTINCT FROM auth.uid()"));
    expect(migration, contains("status = 'pending' AND expires_at <= now()"));
    expect(migration, contains("ON CONFLICT (team_id, invited_user_id) WHERE status = 'pending'"));
  });

  test('invitation acceptance has governorate and roster capacity guards', () {
    final migration = File(
      'supabase/migrations/20261106170000_team_membership_invitations.sql',
    ).readAsStringSync();
    expect(migration, contains("'TEAM_GOVERNORATE_MISMATCH'"));
    expect(migration, contains("count(*) FROM public.team_members WHERE team_id = v_invite.team_id"));
    expect(migration, contains("count(*) FROM public.team_members WHERE user_id = auth.uid()"));
    expect(migration, contains("ON CONFLICT (team_id, user_id) DO NOTHING"));
  });

  test('repository rejects imported draft names and captain self-invites', () {
    final source = File('lib/core/repositories/team_repository.dart').readAsStringSync();
    final start = source.indexOf('Future<String> inviteTeamMember(');
    final end = source.indexOf('Future<void> respondToTeamInvitation(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains("userId.startsWith('guest_')"));
    expect(method, contains('userId == _supabase.auth.currentUser!.id'));
    expect(method, contains("'invite_team_member'"));
  });

}
