import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/services/active_team_service.dart';
import 'package:vsp_application/data/models.dart';

Team _team(String id, String name) => Team(
      id: id,
      name: name,
      captainName: 'Captain',
      captainImageUrl: '',
      date: '',
      stadium: '',
      pricePerPerson: 0,
      currentPlayers: 1,
      maxPlayers: 11,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('resolve restores a verified active team for the same account', () async {
    final first = _team('team-a', 'A');
    final second = _team('team-b', 'B');
    final saved = await ActiveTeamService.select(
      userId: 'user-1',
      teamId: second.id,
      verifiedTeams: <Team>[first, second],
    );

    expect(saved, isTrue);
    expect(
      (await ActiveTeamService.resolve(
        userId: 'user-1',
        teams: <Team>[first, second],
      ))
          ?.id,
      second.id,
    );
  });

  test('select rejects a team outside current verified memberships', () async {
    final saved = await ActiveTeamService.select(
      userId: 'user-1',
      teamId: 'team-b',
      verifiedTeams: <Team>[_team('team-a', 'A')],
    );

    expect(saved, isFalse);
  });

  test('resolve clears a stale selection after the last team is removed', () async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{'active_team_user-1': 'deleted-team'},
    );

    expect(
      await ActiveTeamService.resolve(
        userId: 'user-1',
        teams: const <Team>[],
      ),
      isNull,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('active_team_user-1'), isFalse);
  });

  test('switches teams without leaking the selection to another account',
      () async {
    final first = _team('team-a', 'A');
    final second = _team('team-b', 'B');
    final memberships = <Team>[first, second];

    expect(
      await ActiveTeamService.select(
        userId: 'user-1',
        teamId: first.id,
        verifiedTeams: memberships,
      ),
      isTrue,
    );
    expect(
      await ActiveTeamService.select(
        userId: 'user-1',
        teamId: second.id,
        verifiedTeams: memberships,
      ),
      isTrue,
    );

    expect(
      (await ActiveTeamService.resolve(
        userId: 'user-1',
        teams: memberships,
      ))
          ?.id,
      second.id,
    );
    expect(
      (await ActiveTeamService.resolve(
        userId: 'user-2',
        teams: memberships,
      ))
          ?.id,
      first.id,
      reason: 'A different account must not inherit user-1 selection.',
    );
  });
}
