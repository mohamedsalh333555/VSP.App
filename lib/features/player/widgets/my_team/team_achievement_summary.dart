/// Verified achievement counters for a team profile card.
///
/// Callers must provide server-authoritative, finalized competition results.
/// This helper never treats self-reported results as verified.
class TeamAchievementSummary {
  final int stadiumChampionships;
  final int oneVsOneChampionPlayers;

  const TeamAchievementSummary({
    required this.stadiumChampionships,
    required this.oneVsOneChampionPlayers,
  });

  static TeamAchievementSummary fromVerifiedResults({
    required String teamId,
    required Iterable<String> currentMemberIds,
    required Iterable<TeamChampionshipWin> teamWins,
    required Iterable<OneVsOneChampionshipWin> individualWins,
  }) {
    final championshipIds = <String>{};
    for (final win in teamWins) {
      if (win.winnerTeamId == teamId &&
          win.isFinalized &&
          win.isVerified &&
          win.organizedByStadiumOwner &&
          win.competitionId.isNotEmpty) {
        championshipIds.add(win.competitionId);
      }
    }

    final memberIds = currentMemberIds.where((id) => id.isNotEmpty).toSet();
    final championIds = <String>{};
    for (final win in individualWins) {
      if (win.isFinalized &&
          win.isVerified &&
          win.competitionId.isNotEmpty &&
          memberIds.contains(win.winnerPlayerId)) {
        championIds.add(win.winnerPlayerId);
      }
    }

    return TeamAchievementSummary(
      stadiumChampionships: championshipIds.length,
      oneVsOneChampionPlayers: championIds.length,
    );
  }
}

class TeamChampionshipWin {
  final String competitionId;
  final String winnerTeamId;
  final bool organizedByStadiumOwner;
  final bool isFinalized;
  final bool isVerified;

  const TeamChampionshipWin({
    required this.competitionId,
    required this.winnerTeamId,
    required this.organizedByStadiumOwner,
    required this.isFinalized,
    required this.isVerified,
  });
}

class OneVsOneChampionshipWin {
  final String competitionId;
  final String winnerPlayerId;
  final bool isFinalized;
  final bool isVerified;

  const OneVsOneChampionshipWin({
    required this.competitionId,
    required this.winnerPlayerId,
    required this.isFinalized,
    required this.isVerified,
  });
}
