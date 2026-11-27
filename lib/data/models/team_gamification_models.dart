import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';

enum TeamShieldTier {
  none,
  silver,
  gold,
  diamond,
  elite,
  legendary,
  immortal;

  static TeamShieldTier fromCode(String? code) {
    switch ((code ?? '').trim().toLowerCase()) {
      case 'silver':
      case 'platinum':
        return TeamShieldTier.silver;
      case 'gold':
        return TeamShieldTier.gold;
      case 'diamond':
        return TeamShieldTier.diamond;
      case 'elite':
        return TeamShieldTier.elite;
      case 'legendary':
        return TeamShieldTier.legendary;
      case 'immortal':
        return TeamShieldTier.immortal;
      default:
        return TeamShieldTier.none;
    }
  }

  String get code => name;

  String label(bool isArabic) {
    switch (this) {
      case TeamShieldTier.none:
        return isArabic ? 'بدون درع' : 'No Shield';
      case TeamShieldTier.silver:
        return isArabic ? 'الفضي' : 'Silver';
      case TeamShieldTier.gold:
        return isArabic ? 'الذهبي' : 'Gold';
      case TeamShieldTier.diamond:
        return isArabic ? 'الماسي' : 'Diamond';
      case TeamShieldTier.elite:
        return isArabic ? 'النخبة' : 'Elite';
      case TeamShieldTier.legendary:
        return isArabic ? 'الأسطوري' : 'Legendary';
      case TeamShieldTier.immortal:
        return isArabic ? 'الخالد (Immortal)' : 'Immortal';
    }
  }

  double get requiredXp {
    switch (this) {
      case TeamShieldTier.none:
        return 0;
      case TeamShieldTier.silver:
        return 1500;
      case TeamShieldTier.gold:
        return 3000;
      case TeamShieldTier.diamond:
        return 5000;
      case TeamShieldTier.elite:
        return 8000;
      case TeamShieldTier.legendary:
        return 12000;
      case TeamShieldTier.immortal:
        return 15000;
    }
  }

  int get requiredWeightedChallenges => this == TeamShieldTier.immortal ? 60 : 0;

  TeamShieldTier? get nextTier {
    switch (this) {
      case TeamShieldTier.none:
        return TeamShieldTier.silver;
      case TeamShieldTier.silver:
        return TeamShieldTier.gold;
      case TeamShieldTier.gold:
        return TeamShieldTier.diamond;
      case TeamShieldTier.diamond:
        return TeamShieldTier.elite;
      case TeamShieldTier.elite:
        return TeamShieldTier.legendary;
      case TeamShieldTier.legendary:
        return TeamShieldTier.immortal;
      case TeamShieldTier.immortal:
        return null;
    }
  }

  Color get primaryColor {
    switch (this) {
      case TeamShieldTier.none:
        return VSPDSColors.tierNone;
      case TeamShieldTier.silver:
        return VSPDSColors.tierSilver;
      case TeamShieldTier.gold:
        return VSPDSColors.tierGold;
      case TeamShieldTier.diamond:
        return VSPDSColors.tierDiamond;
      case TeamShieldTier.elite:
        return VSPDSColors.tierElite;
      case TeamShieldTier.legendary:
        return VSPDSColors.tierLegendary;
      case TeamShieldTier.immortal:
        return VSPDSColors.tierImmortal;
    }
  }

  String? get assetPath =>
      this == TeamShieldTier.none ? null : 'assets/images/shields/shield_$name.png';
}

class MonthlyRankingEntry {
  final int rank;
  final String teamId;
  final String teamName;
  final String logoUrl;
  final String governorate;
  final String sportType;
  final int rankingPoints;
  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final TeamShieldTier currentShield;
  final String monthKey;

  const MonthlyRankingEntry({
    required this.rank,
    required this.teamId,
    required this.teamName,
    required this.logoUrl,
    required this.governorate,
    required this.sportType,
    required this.rankingPoints,
    required this.matchesPlayed,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.currentShield,
    required this.monthKey,
  });

  factory MonthlyRankingEntry.fromJson(Map<String, dynamic> j) => MonthlyRankingEntry(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        teamId: (j['team_id'] ?? '').toString(),
        teamName: (j['team_name'] ?? '').toString(),
        logoUrl: (j['logo_url'] ?? '').toString(),
        governorate: (j['governorate'] ?? '').toString(),
        sportType: (j['sport_type'] ?? 'Football').toString(),
        rankingPoints: (j['ranking_points'] as num?)?.toInt() ?? 0,
        matchesPlayed: (j['matches_played'] as num?)?.toInt() ?? 0,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        draws: (j['draws'] as num?)?.toInt() ?? 0,
        losses: (j['losses'] as num?)?.toInt() ?? 0,
        currentShield: TeamShieldTier.fromCode(j['current_shield']?.toString()),
        monthKey: (j['month_key'] ?? '').toString(),
      );
}

enum RankingRewardZone {
  cashRewards,
  freeBooking,
  competition,
}

class VspSeasonRewards {
  const VspSeasonRewards._();

  static const int seasonDurationMonths = 2;
  static const int freeHourMinRank = 6;
  static const int freeHourMaxRank = 10;
  static const int freeHourMaxValueEgp = 180;

  static const Map<int, int> cashPrizesEgp = {
    1: 500,
    2: 350,
    3: 250,
    4: 220,
    5: 180,
  };

  static const List<String> rewardLifecycleStatuses = [
    'pending',
    'approved',
    'available',
    'reserved',
    'redeemed',
    'expired',
    'revoked',
  ];

  static RankingRewardZone zoneForRank(int rank) {
    if (rank >= 1 && rank <= 5) return RankingRewardZone.cashRewards;
    if (rank >= freeHourMinRank && rank <= freeHourMaxRank) {
      return RankingRewardZone.freeBooking;
    }
    return RankingRewardZone.competition;
  }

  static int? cashPrizeForRank(int rank) => cashPrizesEgp[rank];

  static String rewardBadgeLabel(int rank, {required bool isArabic}) {
    final cash = cashPrizeForRank(rank);
    if (cash != null) {
      return isArabic ? '$cash ج.م' : '$cash EGP';
    }
    if (rank >= freeHourMinRank && rank <= freeHourMaxRank) {
      return isArabic ? 'ساعة مجانية' : 'Free 1h';
    }
    return isArabic ? 'منافسة' : 'Compete';
  }

  static String nextTargetSummary(
    MonthlyRankingEntry entry,
    List<MonthlyRankingEntry> entries, {
    required bool isArabic,
  }) {
    final zone = zoneForRank(entry.rank);
    if (zone == RankingRewardZone.cashRewards) {
      final prize = cashPrizeForRank(entry.rank) ?? 0;
      return isArabic
          ? 'منطقة الجوائز النقدية • جائزة حالية $prize ج.م'
          : 'Cash Zone • Current Prize $prize EGP';
    }
    if (zone == RankingRewardZone.freeBooking) {
      final fifth = entries.where((e) => e.rank == 5).firstOrNull;
      final gap = fifth != null ? (fifth.rankingPoints - entry.rankingPoints + 1).clamp(1, 9999) : 1;
      return isArabic
          ? 'حجز ساعة مجانية • باقي $gap نقطة على منطقة الكاش (Top 5)'
          : 'Free 1h Zone • $gap pts to Cash Zone (Top 5)';
    }
    final tenth = entries.where((e) => e.rank == 10).firstOrNull;
    final gap = tenth != null ? (tenth.rankingPoints - entry.rankingPoints + 1).clamp(1, 9999) : 1;
    return isArabic
        ? 'منطقة المنافسة • باقي $gap نقطة على Top 10 (ساعة مجانية)'
        : 'Competition Zone • $gap pts to Top 10 (Free 1h)';
  }
}

class MostActiveTeamEntry {
  final int activityRank;
  final String teamId;
  final String teamName;
  final String logoUrl;
  final String governorate;
  final TeamShieldTier currentShield;
  final int approvedChallenges;
  final double weightedChallenges;
  final double seasonXp;
  final int seasonYear;

  const MostActiveTeamEntry({
    required this.activityRank,
    required this.teamId,
    required this.teamName,
    required this.logoUrl,
    required this.governorate,
    required this.currentShield,
    required this.approvedChallenges,
    required this.weightedChallenges,
    required this.seasonXp,
    required this.seasonYear,
  });

  factory MostActiveTeamEntry.fromJson(Map<String, dynamic> j) => MostActiveTeamEntry(
        activityRank: (j['activity_rank'] as num?)?.toInt() ?? 0,
        teamId: (j['team_id'] ?? '').toString(),
        teamName: (j['team_name'] ?? '').toString(),
        logoUrl: (j['logo_url'] ?? '').toString(),
        governorate: (j['governorate'] ?? '').toString(),
        currentShield: TeamShieldTier.fromCode(j['current_shield']?.toString()),
        approvedChallenges: (j['approved_challenges_count'] as num?)?.toInt() ?? 0,
        weightedChallenges: (j['weighted_challenges_count'] as num?)?.toDouble() ?? 0,
        seasonXp: (j['season_xp'] as num?)?.toDouble() ?? 0,
        seasonYear: (j['season_year'] as num?)?.toInt() ?? 2027,
      );
}

class TeamMissionSummary {
  final int challengesCompleted;
  final int challengeWins;
  final int uniqueOpponents;
  final int tournamentsCompleted;
  final List<String> claimedTiers;

  const TeamMissionSummary({
    required this.challengesCompleted,
    required this.challengeWins,
    required this.uniqueOpponents,
    required this.tournamentsCompleted,
    required this.claimedTiers,
  });

  factory TeamMissionSummary.fromJson(Map<String, dynamic> j) => TeamMissionSummary(
        challengesCompleted: (j['challenges_completed'] as num?)?.toInt() ?? 0,
        challengeWins: (j['challenge_wins'] as num?)?.toInt() ?? 0,
        uniqueOpponents: (j['unique_opponents'] as num?)?.toInt() ?? 0,
        tournamentsCompleted: (j['tournaments_completed'] as num?)?.toInt() ?? 0,
        claimedTiers: List<String>.from(j['claimed_tiers'] ?? const []),
      );

  /// Returns next progressive challenge target (4 -> 6 -> 8 -> 10 -> 12).
  (int target, int nextReward)? get nextChallengeStage {
    const stages = [(4, 200), (6, 150), (8, 250), (10, 350), (12, 500)];
    for (final s in stages) {
      if (challengesCompleted < s.$1) return s;
    }
    return null;
  }

  (int target, int nextReward)? get nextWinStage {
    const stages = [(2, 150), (3, 100), (4, 150), (5, 200), (6, 250)];
    for (final s in stages) {
      if (challengeWins < s.$1) return s;
    }
    return null;
  }

  (int target, int nextReward)? get nextOpponentStage {
    const stages = [(2, 100), (3, 75), (4, 100), (5, 125), (6, 150)];
    for (final s in stages) {
      if (uniqueOpponents < s.$1) return s;
    }
    return null;
  }
}

class ImmortalPlayerSnapshot {
  final String id;
  final String userId;
  final String playerName;
  final bool medalEligible;
  final bool jerseyEligible;
  final bool duplicateSeasonBlocked;
  final String? jerseySize;

  const ImmortalPlayerSnapshot({
    required this.id,
    required this.userId,
    required this.playerName,
    required this.medalEligible,
    required this.jerseyEligible,
    required this.duplicateSeasonBlocked,
    this.jerseySize,
  });

  factory ImmortalPlayerSnapshot.fromJson(Map<String, dynamic> j) => ImmortalPlayerSnapshot(
        id: (j['id'] ?? '').toString(),
        userId: (j['user_id'] ?? '').toString(),
        playerName: (j['player_name'] ?? '').toString(),
        medalEligible: j['medal_eligible'] == true,
        jerseyEligible: j['jersey_eligible'] == true,
        duplicateSeasonBlocked: j['duplicate_season_blocked'] == true,
        jerseySize: j['jersey_size']?.toString(),
      );
}

class ImmortalRewardInfo {
  final String id;
  final String rewardStatus;
  final String deliveryStatus;
  final bool sizesLocked;
  final List<ImmortalPlayerSnapshot> players;

  const ImmortalRewardInfo({
    required this.id,
    required this.rewardStatus,
    required this.deliveryStatus,
    required this.sizesLocked,
    required this.players,
  });

  factory ImmortalRewardInfo.fromJson(Map<String, dynamic> j) => ImmortalRewardInfo(
        id: (j['id'] ?? '').toString(),
        rewardStatus: (j['reward_status'] ?? 'eligible').toString(),
        deliveryStatus: (j['delivery_status'] ?? 'pending').toString(),
        sizesLocked: j['sizes_locked'] == true,
        players: (j['players'] as List<dynamic>? ?? [])
            .map((e) => ImmortalPlayerSnapshot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class MonthlyFreeHourAward {
  final String id;
  final String monthKey;
  final String governorate;
  final String status; // 'issued' | 'redeemed' | 'voided'
  final String? redeemedBookingId;

  const MonthlyFreeHourAward({
    required this.id,
    required this.monthKey,
    required this.governorate,
    required this.status,
    this.redeemedBookingId,
  });

  factory MonthlyFreeHourAward.fromJson(Map<String, dynamic> j) => MonthlyFreeHourAward(
        id: (j['id'] ?? '').toString(),
        monthKey: (j['month_key'] ?? '').toString(),
        governorate: (j['governorate'] ?? '').toString(),
        status: (j['status'] ?? 'issued').toString(),
        redeemedBookingId: j['redeemed_booking_id']?.toString(),
      );
}

class TeamAchievementEntry {
  final String code;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final String category;
  final DateTime? unlockedAt;

  const TeamAchievementEntry({
    required this.code,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.category,
    this.unlockedAt,
  });

  factory TeamAchievementEntry.fromJson(Map<String, dynamic> j) => TeamAchievementEntry(
        code: (j['code'] ?? '').toString(),
        titleAr: (j['title_ar'] ?? '').toString(),
        titleEn: (j['title_en'] ?? '').toString(),
        descriptionAr: (j['description_ar'] ?? '').toString(),
        descriptionEn: (j['description_en'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        unlockedAt: DateTime.tryParse(j['unlocked_at']?.toString() ?? ''),
      );
}

class TeamSeasonHistoryEntry {
  final int yearNumber;
  final TeamShieldTier finalShield;
  final double finalXp;
  final int approvedChallenges;
  final int wins;
  final int draws;
  final int losses;
  final int? bestMonthlyRank;
  final bool immortalAchieved;

  const TeamSeasonHistoryEntry({
    required this.yearNumber,
    required this.finalShield,
    required this.finalXp,
    required this.approvedChallenges,
    required this.wins,
    required this.draws,
    required this.losses,
    this.bestMonthlyRank,
    required this.immortalAchieved,
  });

  factory TeamSeasonHistoryEntry.fromJson(Map<String, dynamic> j) => TeamSeasonHistoryEntry(
        yearNumber: (j['year_number'] as num?)?.toInt() ?? 2027,
        finalShield: TeamShieldTier.fromCode(j['final_shield']?.toString()),
        finalXp: (j['final_xp'] as num?)?.toDouble() ?? 0,
        approvedChallenges: (j['approved_challenges'] as num?)?.toInt() ?? 0,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        draws: (j['draws'] as num?)?.toInt() ?? 0,
        losses: (j['losses'] as num?)?.toInt() ?? 0,
        bestMonthlyRank: (j['best_monthly_rank'] as num?)?.toInt(),
        immortalAchieved: j['immortal_achieved'] == true,
      );
}

class StrongestTeamSkillScore {
  final String testCode;
  final String titleAr;
  final String titleEn;
  final double? rawMetricValue;
  final double normalizedPoints;
  final double maxPoints;
  final double weightedPoints;

  const StrongestTeamSkillScore({
    required this.testCode,
    required this.titleAr,
    required this.titleEn,
    this.rawMetricValue,
    required this.normalizedPoints,
    required this.maxPoints,
    required this.weightedPoints,
  });

  factory StrongestTeamSkillScore.fromJson(Map<String, dynamic> j) => StrongestTeamSkillScore(
        testCode: (j['test_code'] ?? '').toString(),
        titleAr: (j['title_ar'] ?? '').toString(),
        titleEn: (j['title_en'] ?? '').toString(),
        rawMetricValue: (j['raw_metric_value'] as num?)?.toDouble(),
        normalizedPoints: (j['normalized_points'] as num?)?.toDouble() ?? 0,
        maxPoints: (j['max_points'] as num?)?.toDouble() ?? 100,
        weightedPoints: (j['weighted_points'] as num?)?.toDouble() ?? 0,
      );
}

class StrongestTeamParticipationResult {
  final String eventId;
  final String titleAr;
  final String titleEn;
  final DateTime? eventDate;
  final int? finalRank;
  final double totalWeightedScore;
  final double xpAwarded;
  final List<StrongestTeamSkillScore> scores;

  const StrongestTeamParticipationResult({
    required this.eventId,
    required this.titleAr,
    required this.titleEn,
    this.eventDate,
    this.finalRank,
    required this.totalWeightedScore,
    required this.xpAwarded,
    required this.scores,
  });

  factory StrongestTeamParticipationResult.fromJson(Map<String, dynamic> j) => StrongestTeamParticipationResult(
        eventId: (j['event_id'] ?? '').toString(),
        titleAr: (j['title_ar'] ?? '').toString(),
        titleEn: (j['title_en'] ?? '').toString(),
        eventDate: DateTime.tryParse(j['event_date']?.toString() ?? ''),
        finalRank: (j['final_rank'] as num?)?.toInt(),
        totalWeightedScore: (j['total_weighted_score'] as num?)?.toDouble() ?? 0,
        xpAwarded: (j['xp_awarded'] as num?)?.toDouble() ?? 0,
        scores: (j['scores'] as List<dynamic>? ?? [])
            .map((e) => StrongestTeamSkillScore.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class TeamGamificationProfile {
  final bool isMember;
  final bool isCaptain;
  final String seasonNameAr;
  final String seasonNameEn;
  final int seasonYear;
  final bool isOfficialLive;
  final double seasonXp;
  final double lifetimeXp;
  final TeamShieldTier currentShield;
  final TeamShieldTier highestHistoricalShield;
  final int approvedChallenges;
  final double weightedChallenges;
  final int immortalCount;
  final int? monthlyRank;
  final String monthKey;
  final int monthlyRankingPoints;
  final int monthlyWins;
  final int monthlyDraws;
  final int monthlyLosses;
  final TeamMissionSummary? missions;
  final ImmortalRewardInfo? immortalReward;
  final List<MonthlyFreeHourAward> freeHourAwards;
  final List<TeamAchievementEntry> achievements;
  final List<TeamSeasonHistoryEntry> seasonHistory;
  final List<StrongestTeamParticipationResult> strongestTeamResults;

  const TeamGamificationProfile({
    required this.isMember,
    required this.isCaptain,
    required this.seasonNameAr,
    required this.seasonNameEn,
    required this.seasonYear,
    required this.isOfficialLive,
    required this.seasonXp,
    required this.lifetimeXp,
    required this.currentShield,
    required this.highestHistoricalShield,
    required this.approvedChallenges,
    required this.weightedChallenges,
    required this.immortalCount,
    this.monthlyRank,
    required this.monthKey,
    required this.monthlyRankingPoints,
    required this.monthlyWins,
    required this.monthlyDraws,
    required this.monthlyLosses,
    this.missions,
    this.immortalReward,
    required this.freeHourAwards,
    required this.achievements,
    required this.seasonHistory,
    required this.strongestTeamResults,
  });

  factory TeamGamificationProfile.fromJson(Map<String, dynamic> j) {
    final s = Map<String, dynamic>.from(j['season'] as Map? ?? const {});
    final p = Map<String, dynamic>.from(j['progress'] as Map? ?? const {});
    final r = Map<String, dynamic>.from(j['monthly_ranking'] as Map? ?? const {});
    return TeamGamificationProfile(
      isMember: j['is_member'] == true,
      isCaptain: j['is_captain'] == true,
      seasonNameAr: (s['name_ar'] ?? 'الموسم الأول 2027').toString(),
      seasonNameEn: (s['name_en'] ?? 'Season 1 — 2027').toString(),
      seasonYear: (s['year'] as num?)?.toInt() ?? 2027,
      isOfficialLive: s['is_official_live'] == true,
      seasonXp: (p['season_xp'] as num?)?.toDouble() ?? 0,
      lifetimeXp: (p['lifetime_xp'] as num?)?.toDouble() ?? 0,
      currentShield: TeamShieldTier.fromCode(p['current_shield']?.toString()),
      highestHistoricalShield: TeamShieldTier.fromCode(p['highest_historical_shield']?.toString()),
      approvedChallenges: (p['approved_challenges'] as num?)?.toInt() ?? 0,
      weightedChallenges: (p['weighted_challenges'] as num?)?.toDouble() ?? 0,
      immortalCount: (p['immortal_count'] as num?)?.toInt() ?? 0,
      monthlyRank: (r['rank'] as num?)?.toInt(),
      monthKey: (r['month_key'] ?? '').toString(),
      monthlyRankingPoints: (r['ranking_points'] as num?)?.toInt() ?? 0,
      monthlyWins: (r['wins'] as num?)?.toInt() ?? 0,
      monthlyDraws: (r['draws'] as num?)?.toInt() ?? 0,
      monthlyLosses: (r['losses'] as num?)?.toInt() ?? 0,
      missions: j['missions'] is Map ? TeamMissionSummary.fromJson(Map<String, dynamic>.from(j['missions'] as Map)) : null,
      immortalReward: j['immortal_reward'] is Map ? ImmortalRewardInfo.fromJson(Map<String, dynamic>.from(j['immortal_reward'] as Map)) : null,
      freeHourAwards: (j['free_hour_awards'] as List<dynamic>? ?? [])
          .map((e) => MonthlyFreeHourAward.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      achievements: (j['achievements'] as List<dynamic>? ?? [])
          .map((e) => TeamAchievementEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      seasonHistory: (j['season_history'] as List<dynamic>? ?? [])
          .map((e) => TeamSeasonHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      strongestTeamResults: (j['strongest_team_results'] as List<dynamic>? ?? [])
          .map((e) => StrongestTeamParticipationResult.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class StrongestTeamEvent {
  final String id;
  final String titleAr;
  final String titleEn;
  final String governorate;
  final String venueName;
  final DateTime eventDate;
  final double entryFeeEgp;
  final String status;
  final String? rulesSummaryAr;
  final String? rulesSummaryEn;
  final String? prizeDescriptionAr;
  final String? prizeDescriptionEn;
  final String? bestGkAwardRulesAr;
  final String? bestGkAwardRulesEn;
  final List<Map<String, dynamic>> tests;
  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> scores;

  const StrongestTeamEvent({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.governorate,
    required this.venueName,
    required this.eventDate,
    required this.entryFeeEgp,
    required this.status,
    this.rulesSummaryAr,
    this.rulesSummaryEn,
    this.prizeDescriptionAr,
    this.prizeDescriptionEn,
    this.bestGkAwardRulesAr,
    this.bestGkAwardRulesEn,
    this.tests = const [],
    this.participants = const [],
    this.scores = const [],
  });

  factory StrongestTeamEvent.fromJson(Map<String, dynamic> j) => StrongestTeamEvent(
        id: (j['id'] ?? '').toString(),
        titleAr: (j['title_ar'] ?? '').toString(),
        titleEn: (j['title_en'] ?? '').toString(),
        governorate: (j['governorate'] ?? '').toString(),
        venueName: (j['venue_name'] ?? '').toString(),
        eventDate: DateTime.tryParse(j['event_date']?.toString() ?? '') ?? DateTime.now(),
        entryFeeEgp: (j['entry_fee_egp'] as num?)?.toDouble() ?? 50.0,
        status: (j['status'] ?? 'draft').toString(),
        rulesSummaryAr: j['rules_summary_ar']?.toString(),
        rulesSummaryEn: j['rules_summary_en']?.toString(),
        prizeDescriptionAr: j['prize_description_ar']?.toString(),
        prizeDescriptionEn: j['prize_description_en']?.toString(),
        bestGkAwardRulesAr: j['best_gk_award_rules_ar']?.toString(),
        bestGkAwardRulesEn: j['best_gk_award_rules_en']?.toString(),
        tests: List<Map<String, dynamic>>.from((j['strongest_team_tests'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))),
        participants: List<Map<String, dynamic>>.from((j['strongest_team_participants'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))),
        scores: List<Map<String, dynamic>>.from((j['strongest_team_scores'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))),
      );
}
