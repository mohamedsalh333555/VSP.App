import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invitation inbox resolves names from public team view', () {
    final repository = File('lib/core/repositories/team_repository.dart').readAsStringSync();
    final start = repository.indexOf('Future<List<Map<String, dynamic>>> getPendingTeamInvitations(');
    final end = repository.indexOf('Future<void> addMemberToTeam(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = repository.substring(start, end);
    expect(method, contains(".from('teams_public')"));
    expect(method, contains(".select('id, name')"));
    expect(method, contains("invite['team_name']"));
    expect(method, contains('return invitations;'));
  });

  test('invitation list does not expose team UUID as display label', () {
    final source = File('lib/features/player/widgets/team_invitations_sheet.dart').readAsStringSync();
    expect(source, contains("invitation['team_name']"));
    expect(source, contains('Team unavailable'));
    expect(source, isNot(contains("subtitle: Text(invitation['team_id'].toString())")));
  });
}
