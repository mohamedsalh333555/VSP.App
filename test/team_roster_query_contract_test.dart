import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('roster profiles use one authorized server RPC without a preflight query', () {
    final source = File(
      'lib/core/repositories/team/team_roster_coordinator.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<List<Map<String, String>>> getTeamMemberProfiles(');
    final end = source.indexOf('Future<void> addMemberToTeam(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains("'get_team_member_profiles'"));
    expect(method, contains("'p_team_id': teamId"));
    expect(method, isNot(contains('getTeamMemberUids(teamId)')));
    expect(method, isNot(contains(".from('team_members')")));
  });
}
