import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/team_profile/team_profile_stats_grid.dart';

void main() {
  test('member count is unknown until membership source succeeds', () {
    expect(TeamProfileStatsGrid.memberCountText(null), '—');
    expect(TeamProfileStatsGrid.memberCountText(-1), '—');
    expect(TeamProfileStatsGrid.memberCountText(0), '0');
    expect(TeamProfileStatsGrid.memberCountText(5), '5');
  });

  test('team profile no longer trusts the stale embedded member list', () {
    final source = File(
      'lib/features/player/screens/team_profile_screen.dart',
    ).readAsStringSync();
    final start = source.indexOf('int? get _teamMemberCount');
    final end = source.indexOf('Future<void> _generateMatchupInviteCode()', start);
    expect(start, isNonNegative);
    expect(end, greaterThan(start));
    final logic = source.substring(start, end);
    expect(logic, contains('if (_verifiedMemberIds == null) return null;'));
    expect(logic, isNot(contains('team.memberUids.where')));
    expect(logic, contains('team.captainId'));
  });

  test('member count unavailable is spoken clearly, not presented as zero', () {
    final source = File(
      'lib/features/player/widgets/team_profile/team_profile_stats_grid.dart',
    ).readAsStringSync();
    expect(source, contains("isArabic ? 'غير متاح' : 'Unavailable'"));
    expect(source, contains("spokenValue ?? value"));
    expect(source, isNot(contains('totalMembersCount.toString()')));
  });
}
