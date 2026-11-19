/// Guards the private team challenge code against stale asynchronous results.
/// A successful server response alone is never permission to reveal a code.
class TeamMatchupInviteGuard {
  const TeamMatchupInviteGuard._();

  static bool canReveal({
    required String? requestedTeamId,
    required String? displayedTeamId,
    required String? requestedAccountId,
    required String? activeAccountId,
    required String? captainId,
    required int requestVersion,
    required int currentVersion,
  }) {
    final team = requestedTeamId?.trim();
    final actor = requestedAccountId?.trim();
    if (team == null || team.isEmpty || actor == null || actor.isEmpty) {
      return false;
    }
    return requestVersion == currentVersion &&
        displayedTeamId?.trim() == team &&
        activeAccountId?.trim() == actor &&
        captainId?.trim() == actor;
  }
}
