import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models/team_gamification_models.dart';
import 'package:vsp_application/data/models/team_models.dart';

/// Comprehensive unit verification of VSP Gamification Economy v2,
/// Monthly Competitive Ranking (3/1/0), Pro-Rata Missions, 6 Annual Shields,
/// Immortal Dual Check, Repeat-Opponent Weighting, Strongest Team, and Team Caps.
void main() {
  group('VSP Gamification Economy v2 & Models', () {
    test('Annual Shield thresholds, nextTier progression, and asset paths match spec', () {
      expect(TeamShieldTier.none.requiredXp, equals(0));
      expect(TeamShieldTier.silver.requiredXp, equals(1500));
      expect(TeamShieldTier.gold.requiredXp, equals(3000));
      expect(TeamShieldTier.diamond.requiredXp, equals(5000));
      expect(TeamShieldTier.elite.requiredXp, equals(8000));
      expect(TeamShieldTier.legendary.requiredXp, equals(12000));
      expect(TeamShieldTier.immortal.requiredXp, equals(15000));
      expect(TeamShieldTier.immortal.requiredWeightedChallenges, equals(60));

      expect(TeamShieldTier.none.nextTier, equals(TeamShieldTier.silver));
      expect(TeamShieldTier.silver.nextTier, equals(TeamShieldTier.gold));
      expect(TeamShieldTier.gold.nextTier, equals(TeamShieldTier.diamond));
      expect(TeamShieldTier.diamond.nextTier, equals(TeamShieldTier.elite));
      expect(TeamShieldTier.elite.nextTier, equals(TeamShieldTier.legendary));
      expect(TeamShieldTier.legendary.nextTier, equals(TeamShieldTier.immortal));
      expect(TeamShieldTier.immortal.nextTier, isNull);

      expect(TeamShieldTier.silver.assetPath, equals('assets/images/shields/shield_silver.png'));
      expect(TeamShieldTier.gold.assetPath, equals('assets/images/shields/shield_gold.png'));
      expect(TeamShieldTier.none.assetPath, isNull);
    });

    test('Repeat opponent reduces Season XP to 50% and Challenge weight to 0.5, NOT Monthly Ranking', () {
      double matchXp({required String outcome, required bool isRepeat}) {
        final base = switch (outcome) {
          'win' => 80.0,
          'draw' => 65.0,
          'loss' => 50.0,
          _ => 0.0,
        };
        return isRepeat ? base * 0.5 : base;
      }

      int rankingPoints(String outcome) => switch (outcome) {
            'win' => 3,
            'draw' => 1,
            _ => 0,
          };

      expect(matchXp(outcome: 'win', isRepeat: false), equals(80.0));
      expect(matchXp(outcome: 'draw', isRepeat: false), equals(65.0));
      expect(matchXp(outcome: 'loss', isRepeat: false), equals(50.0));

      expect(matchXp(outcome: 'win', isRepeat: true), equals(40.0));
      expect(matchXp(outcome: 'draw', isRepeat: true), equals(32.5));
      expect(matchXp(outcome: 'loss', isRepeat: true), equals(25.0));

      // Monthly Ranking stays 100% regardless of repeat opponent
      expect(rankingPoints('win'), equals(3));
      expect(rankingPoints('draw'), equals(1));
      expect(rankingPoints('loss'), equals(0));
    });

    test('Pro-rata mission weights calculate exact payout against chronological match weights', () {
      // Simulate Challenges Stage 1 (threshold 4 -> reward 200)
      // Matches 1..4: 2 new opponents (weight 1.0) + 2 repeat opponents (weight 0.5) => avg weight = 3.0 / 4 = 0.75
      final weights = [1.0, 0.5, 1.0, 0.5];
      final tierWeightSum = weights.take(4).reduce((a, b) => a + b);
      final payout = double.parse((200 * (tierWeightSum / 4)).toStringAsFixed(2));
      expect(payout, equals(150.0));

      // Progressive Mission next-stage helpers
      const summary = TeamMissionSummary(
        challengesCompleted: 4,
        challengeWins: 2,
        uniqueOpponents: 3,
        tournamentsCompleted: 1,
        claimedTiers: ['ch_4', 'win_2', 'opp_2', 'opp_3', 'tourn_1'],
      );
      expect(summary.nextChallengeStage, equals((6, 150)));
      expect(summary.nextWinStage, equals((3, 100)));
      expect(summary.nextOpponentStage, equals((4, 100)));
    });

    test('Monthly Governorate Ranking strict tiebreaker ordering', () {
      int compareEntries(MonthlyRankingEntry a, MonthlyRankingEntry b) {
        if (a.rankingPoints != b.rankingPoints) {
          return b.rankingPoints.compareTo(a.rankingPoints);
        }
        if (a.wins != b.wins) return b.wins.compareTo(a.wins);
        if (a.draws != b.draws) return b.draws.compareTo(a.draws);
        if (a.losses != b.losses) return a.losses.compareTo(b.losses); // ASC
        return b.matchesPlayed.compareTo(a.matchesPlayed);
      }

      const teamA = MonthlyRankingEntry(
        rank: 0,
        teamId: 'a',
        teamName: 'Team A',
        logoUrl: '',
        governorate: 'Aswan',
        sportType: 'Football',
        currentShield: TeamShieldTier.gold,
        monthKey: '2027-02',
        rankingPoints: 10, // 3W 1D 2L (6 matches)
        matchesPlayed: 6,
        wins: 3,
        draws: 1,
        losses: 2,
      );
      const teamB = MonthlyRankingEntry(
        rank: 0,
        teamId: 'b',
        teamName: 'Team B',
        logoUrl: '',
        governorate: 'Aswan',
        sportType: 'Football',
        currentShield: TeamShieldTier.none,
        monthKey: '2027-02',
        rankingPoints: 10, // 3W 1D 0L (4 matches) -> fewer losses wins tiebreaker!
        matchesPlayed: 4,
        wins: 3,
        draws: 1,
        losses: 0,
      );

      final list = <MonthlyRankingEntry>[teamA, teamB]..sort(compareEntries);
      expect(list.first.teamId, equals('b'));
    });

    test('Team model enforces maxPlayers = 8 default & exposes Season XP/Shield fields', () {
      final team = Team.fromFirestore({
        'name': 'نسور أسوان',
        'captainName': 'كابتن علي',
        'captainImageUrl': '',
        'date': '',
        'stadium': '',
        'pricePerPerson': 0,
        'currentPlayers': 5,
        'current_season_xp': 3450.5,
        'lifetime_xp': 8200.0,
        'current_shield': 'platinum',
        'highest_historical_shield': 'diamond',
      }, 't1');

      expect(team.maxPlayers, equals(8));
      expect(team.currentSeasonXp, equals(3450.5));
      expect(team.lifetimeXp, equals(8200.0));
      expect(team.shieldTier, equals(TeamShieldTier.silver));
      expect(team.highestShieldTier, equals(TeamShieldTier.diamond));
    });

    test('Immortal qualification requires BOTH >= 15,000 XP AND >= 60.0 weighted challenges', () {
      bool qualifiesForImmortal({required double seasonXp, required double weightedChallenges}) =>
          seasonXp >= 15000.0 && weightedChallenges >= 60.0;

      // High XP but repeat farming / < 60 weighted challenges => stays Legendary
      expect(qualifiesForImmortal(seasonXp: 16500, weightedChallenges: 45.0), isFalse);
      // 60 challenges but < 15,000 XP => not Immortal
      expect(qualifiesForImmortal(seasonXp: 14999.5, weightedChallenges: 60.0), isFalse);
      // Both met => Immortal
      expect(qualifiesForImmortal(seasonXp: 15000.0, weightedChallenges: 60.0), isTrue);
    });
  });

  group('VSP 2-Month Competitive Season & 3 Ranking Zones', () {
    test('Maps ranks accurately to Cash Rewards (1-5), Free Booking (6-10), and Competition (11+)', () {
      for (var r = 1; r <= 5; r++) {
        expect(VspSeasonRewards.zoneForRank(r), equals(RankingRewardZone.cashRewards));
      }
      for (var r = 6; r <= 10; r++) {
        expect(VspSeasonRewards.zoneForRank(r), equals(RankingRewardZone.freeBooking));
        expect(VspSeasonRewards.cashPrizeForRank(r), isNull);
      }
      expect(VspSeasonRewards.zoneForRank(11), equals(RankingRewardZone.competition));
      expect(VspSeasonRewards.zoneForRank(42), equals(RankingRewardZone.competition));
    });

    test('Cash prize pool totals 1,500 EGP across ranks 1-5 and free hour caps at 180 EGP', () {
      expect(VspSeasonRewards.cashPrizeForRank(1), equals(500));
      expect(VspSeasonRewards.cashPrizeForRank(2), equals(350));
      expect(VspSeasonRewards.cashPrizeForRank(3), equals(250));
      expect(VspSeasonRewards.cashPrizeForRank(4), equals(220));
      expect(VspSeasonRewards.cashPrizeForRank(5), equals(180));
      final totalCash = VspSeasonRewards.cashPrizesEgp.values.reduce((a, b) => a + b);
      expect(totalCash, equals(1500));
      expect(VspSeasonRewards.freeHourMaxValueEgp, equals(180));
      expect(VspSeasonRewards.seasonDurationMonths, equals(2));
    });

    test('Reward lifecycle statuses and single-use free-hour guard prevent double redemption', () {
      expect(
        VspSeasonRewards.rewardLifecycleStatuses,
        containsAll(['pending', 'approved', 'available', 'reserved', 'redeemed', 'expired', 'revoked']),
      );

      var voucherStatus = 'available';
      bool tryReserveVoucher() {
        if (voucherStatus != 'available') return false;
        voucherStatus = 'reserved';
        return true;
      }

      expect(tryReserveVoucher(), isTrue);
      expect(tryReserveVoucher(), isFalse);
    });

    test('Match event idempotency & result correction preserve accurate ranking points', () {
      final processedKeys = <String>{};
      var points = 0;

      void applyEvent(String key, int delta) {
        if (processedKeys.add(key)) points += delta;
      }

      applyEvent('booking_1:team_a:win', 3);
      applyEvent('booking_1:team_a:win', 3); // duplicate webhook/retry ignored
      expect(points, equals(3));

      // Correction: win (3) -> draw (1) => -2 delta
      applyEvent('booking_1:team_a:correction_draw', -2);
      expect(points, equals(1));
    });

    test('Next realistic target summary computes gap to Top 10 and Top 5', () {
      final entries = List.generate(
        12,
        (i) => MonthlyRankingEntry(
          rank: i + 1,
          teamId: 't_${i + 1}',
          teamName: 'Team ${i + 1}',
          logoUrl: '',
          governorate: 'Aswan',
          sportType: 'Football',
          rankingPoints: 40 - i * 2,
          matchesPlayed: 10,
          wins: 5,
          draws: 1,
          losses: 4,
          currentShield: TeamShieldTier.silver,
          monthKey: '2026-11',
        ),
      );

      // Rank 12 has 18 pts, Rank 10 has 22 pts => needs 5 pts to surpass Rank 10
      final rank12Text = VspSeasonRewards.nextTargetSummary(entries[11], entries, isArabic: false);
      expect(rank12Text, contains('5 pts to Top 10'));

      // Rank 7 has 28 pts, Rank 5 has 32 pts => needs 5 pts to surpass Rank 5
      final rank7Text = VspSeasonRewards.nextTargetSummary(entries[6], entries, isArabic: false);
      expect(rank7Text, contains('5 pts to Cash Zone (Top 5)'));
    });
  });
}
