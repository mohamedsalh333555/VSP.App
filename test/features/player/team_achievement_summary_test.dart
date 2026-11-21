import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/my_team/team_achievement_summary.dart';

void main() {
  test('only verified stadium-owner championships count, deduplicated', () {
    const valid = TeamChampionshipWin(
      competitionId: 'owner-cup',
      winnerTeamId: 'team-a',
      organizedByStadiumOwner: true,
      isFinalized: true,
      isVerified: true,
    );
    const playerOrganized = TeamChampionshipWin(
      competitionId: 'player-cup',
      winnerTeamId: 'team-a',
      organizedByStadiumOwner: false,
      isFinalized: true,
      isVerified: true,
    );
    const pending = TeamChampionshipWin(
      competitionId: 'pending-cup',
      winnerTeamId: 'team-a',
      organizedByStadiumOwner: true,
      isFinalized: false,
      isVerified: true,
    );
    const otherTeam = TeamChampionshipWin(
      competitionId: 'other-cup',
      winnerTeamId: 'team-b',
      organizedByStadiumOwner: true,
      isFinalized: true,
      isVerified: true,
    );
    final summary = TeamAchievementSummary.fromVerifiedResults(
      teamId: 'team-a',
      currentMemberIds: const [],
      teamWins: const [valid, valid, playerOrganized, pending, otherTeam],
      individualWins: const [],
    );
    expect(summary.stadiumChampionships, 1);
  });

  test('1v1 badge counts distinct current champion players, not titles', () {
    const first = OneVsOneChampionshipWin(
      competitionId: 'one',
      winnerPlayerId: 'player-a',
      isFinalized: true,
      isVerified: true,
    );
    const second = OneVsOneChampionshipWin(
      competitionId: 'two',
      winnerPlayerId: 'player-a',
      isFinalized: true,
      isVerified: true,
    );
    const formerMember = OneVsOneChampionshipWin(
      competitionId: 'three',
      winnerPlayerId: 'player-old',
      isFinalized: true,
      isVerified: true,
    );
    const unverified = OneVsOneChampionshipWin(
      competitionId: 'four',
      winnerPlayerId: 'player-b',
      isFinalized: true,
      isVerified: false,
    );
    final summary = TeamAchievementSummary.fromVerifiedResults(
      teamId: 'team-a',
      currentMemberIds: const ['player-a', 'player-b'],
      teamWins: const [],
      individualWins: const [first, second, formerMember, unverified],
    );
    expect(summary.oneVsOneChampionPlayers, 1);
  });

  test('zero achievements remain zero when no verified wins exist', () {
    final summary = TeamAchievementSummary.fromVerifiedResults(
      teamId: 'team-a',
      currentMemberIds: const ['player-a'],
      teamWins: const [],
      individualWins: const [],
    );
    expect(summary.stadiumChampionships, 0);
    expect(summary.oneVsOneChampionPlayers, 0);
  });
  test('membership changes update the distinct 1v1 champion count', () {
    const titles = [
      OneVsOneChampionshipWin(
        competitionId: 'cup-a',
        winnerPlayerId: 'p1',
        isFinalized: true,
        isVerified: true,
      ),
      OneVsOneChampionshipWin(
        competitionId: 'cup-b',
        winnerPlayerId: 'p2',
        isFinalized: true,
        isVerified: true,
      ),
      OneVsOneChampionshipWin(
        competitionId: 'cup-c',
        winnerPlayerId: 'p1',
        isFinalized: true,
        isVerified: true,
      ),
    ];
    TeamAchievementSummary summary(List<String> members) =>
        TeamAchievementSummary.fromVerifiedResults(
          teamId: 'team',
          currentMemberIds: members,
          teamWins: const [],
          individualWins: titles,
        );
    expect(summary(['p1']).oneVsOneChampionPlayers, 1);
    expect(summary(['p1', 'p2']).oneVsOneChampionPlayers, 2);
    expect(summary(['p2']).oneVsOneChampionPlayers, 1);
    expect(summary([]).oneVsOneChampionPlayers, 0);
  });

  test('unverified and unfinished individual titles never count', () {
    const titles = [
      OneVsOneChampionshipWin(
        competitionId: 'unverified',
        winnerPlayerId: 'p1',
        isFinalized: true,
        isVerified: false,
      ),
      OneVsOneChampionshipWin(
        competitionId: 'pending',
        winnerPlayerId: 'p2',
        isFinalized: false,
        isVerified: true,
      ),
    ];
    final summary = TeamAchievementSummary.fromVerifiedResults(
      teamId: 'team',
      currentMemberIds: const ['p1', 'p2'],
      teamWins: const [],
      individualWins: titles,
    );
    expect(summary.oneVsOneChampionPlayers, 0);
  });

  test('distinct opponent count excludes duplicate and blank team IDs', () {
    expect(countDistinctTeamOpponents(['A', 'A', ' B ', '', '  ', 'C']), 3);
    expect(countDistinctTeamOpponents([]), 0);
  });
}
