import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/services/team_matchup_invite_guard.dart';

void main() {
  bool mayReveal({
    String? requestedTeamId = 'team-a',
    String? displayedTeamId = 'team-a',
    String? requestedAccountId = 'captain-a',
    String? activeAccountId = 'captain-a',
    String? captainId = 'captain-a',
    int requestVersion = 2,
    int currentVersion = 2,
  }) =>
      TeamMatchupInviteGuard.canReveal(
        requestedTeamId: requestedTeamId,
        displayedTeamId: displayedTeamId,
        requestedAccountId: requestedAccountId,
        activeAccountId: activeAccountId,
        captainId: captainId,
        requestVersion: requestVersion,
        currentVersion: currentVersion,
      );

  test('captain may reveal only the current team's current request', () {
    expect(mayReveal(), isTrue);
    expect(mayReveal(requestVersion: 1), isFalse);
    expect(mayReveal(currentVersion: 3), isFalse);
    expect(mayReveal(displayedTeamId: 'team-b'), isFalse);
    expect(mayReveal(displayedTeamId: null), isFalse);
  });

  test('switching accounts or losing captain status revokes pending codes', () {
    expect(mayReveal(activeAccountId: 'captain-b'), isFalse);
    expect(mayReveal(activeAccountId: null), isFalse);
    expect(mayReveal(captainId: 'captain-b'), isFalse);
    expect(mayReveal(captainId: null), isFalse);
    expect(mayReveal(requestedAccountId: null), isFalse);
  });

  test('never disclose for blank team or actor identifiers', () {
    expect(mayReveal(requestedTeamId: ''), isFalse);
    expect(mayReveal(requestedTeamId: '   '), isFalse);
    expect(mayReveal(requestedTeamId: null), isFalse);
    expect(mayReveal(requestedAccountId: '   '), isFalse);
  });

  test('comparison trims incidental whitespace without mixing identities', () {
    expect(mayReveal(
      requestedTeamId: ' team-a ',
      requestedAccountId: ' captain-a ',
    ), isTrue);
    expect(mayReveal(activeAccountId: 'captain-c'), isFalse);
  });
}
