import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('team invitation requires a usable identifier from the server', () {
    final source = File('lib/core/repositories/team_repository.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<String> inviteTeamMember(');
    final end = source.indexOf('Future<void> respondToTeamInvitation(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains("response['success'] != true"));
    expect(method, contains("response['invitation_id']?.toString()"));
    expect(method, contains('invitationId.trim().isEmpty'));
    expect(method, contains("invitationId == 'null'"));
    expect(method.indexOf('invitationId.trim().isEmpty'),
        lessThan(method.indexOf('return invitationId;')));
  });
  test('accept and decline reject invalid invitation IDs before RPC', () {
    final source = File('lib/core/repositories/team_repository.dart')
        .readAsStringSync();
    final start = source.indexOf('Future<void> respondToTeamInvitation(');
    final end = source.indexOf('Future<List<Map<String, dynamic>>> getPendingTeamInvitations(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains('invitationId.trim().isEmpty'));
    expect(method, contains("invitationId == 'null'"));
    expect(method.indexOf('throw ArgumentError.value('),
        lessThan(method.indexOf("'respond_team_membership_invitation'")));
    expect(method, contains("response is! Map || response['success'] != true"));
  });

}
