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
}
