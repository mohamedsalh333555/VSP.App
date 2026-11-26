import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models/team_gamification_models.dart';
import 'package:vsp_application/data/models/team_models.dart';
import 'package:vsp_application/features/player/widgets/challenge_result_breakdown_dialog.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/widgets/shields/vsp_shield_badge.dart';
import 'package:vsp_application/shared/widgets/team_gamification_panel.dart';

Widget _wrapArabic(Widget child) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  final sampleTeam = Team(
    id: 'team-1',
    name: 'نجوم أسوان',
    captainId: 'cap-1',
    captainName: 'أحمد',
    captainImageUrl: '',
    date: '',
    stadium: '',
    pricePerPerson: 0,
    currentPlayers: 6,
    maxPlayers: 8,
    currentSeasonXp: 15400,
    lifetimeXp: 15400,
    currentShield: 'immortal',
    highestHistoricalShield: 'immortal',
    immortalCount: 1,
  );

  final sampleProfile = TeamGamificationProfile(
    isMember: true,
    isCaptain: true,
    seasonNameAr: 'الموسم الأول 2027',
    seasonNameEn: 'Season 1 — 2027',
    seasonYear: 2027,
    isOfficialLive: true,
    seasonXp: 15400,
    lifetimeXp: 15400,
    currentShield: TeamShieldTier.immortal,
    highestHistoricalShield: TeamShieldTier.immortal,
    approvedChallenges: 74,
    weightedChallenges: 61.5,
    immortalCount: 1,
    monthlyRank: 1,
    monthKey: '2027-05',
    monthlyRankingPoints: 18,
    monthlyWins: 6,
    monthlyDraws: 0,
    monthlyLosses: 1,
    missions: const TeamMissionSummary(
      challengesCompleted: 6,
      challengeWins: 4,
      uniqueOpponents: 5,
      tournamentsCompleted: 1,
      claimedTiers: ['ch_4', 'ch_6'],
    ),
    immortalReward: const ImmortalRewardInfo(
      id: 'ent-1',
      rewardStatus: 'eligible',
      deliveryStatus: 'pending',
      sizesLocked: false,
      players: [
        ImmortalPlayerSnapshot(
          id: 'snap-1',
          userId: 'cap-1',
          playerName: 'أحمد الكابتن',
          medalEligible: true,
          jerseyEligible: true,
          duplicateSeasonBlocked: false,
          jerseySize: 'L',
        ),
      ],
    ),
    freeHourAwards: const [
      MonthlyFreeHourAward(
        id: 'award-1',
        monthKey: '2027-04',
        governorate: 'Aswan',
        status: 'issued',
      ),
    ],
    achievements: const [
      TeamAchievementEntry(
        code: 'immortal',
        titleAr: 'الخالدون',
        titleEn: 'Immortal',
        descriptionAr: 'الوصول لدرع الخلود.',
        descriptionEn: 'Reached Immortal Shield.',
        category: 'immortal',
      ),
    ],
    seasonHistory: const [],
    strongestTeamResults: const [
      StrongestTeamParticipationResult(
        eventId: 'ev-1',
        titleAr: 'أقوى فريق أسوان',
        titleEn: 'Strongest Team Aswan',
        finalRank: 1,
        totalWeightedScore: 485.0,
        xpAwarded: 1400,
        scores: [],
      ),
    ],
  );

  testWidgets('VspShieldBadge renders all 7 shield tiers cleanly', (tester) async {
    for (final tier in TeamShieldTier.values) {
      await tester.pumpWidget(
        _wrapArabic(VspShieldBadge(tier: tier, size: 56, showLabel: true)),
      );
      expect(find.text(tier.label(true)), findsOneWidget);
    }
  });

  testWidgets('TeamGamificationPanel private view uses exact "جائزة خاصة من VSP" label and hides physical components', (tester) async {
    await tester.pumpWidget(
      _wrapArabic(
        TeamGamificationPanel(
          profile: sampleProfile,
          team: sampleTeam,
          isPrivateView: true,
          currentUserId: 'cap-1',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('جائزة خاصة من VSP'), findsOneWidget);
    expect(find.textContaining('المهام الشهرية المتدرجة'), findsOneWidget);
    expect(find.textContaining('جوائز بطل الشهر'), findsOneWidget);
    expect(find.textContaining('61.5 / 60'), findsOneWidget);
    expect(find.textContaining('إجمالي التحديات: 74'), findsOneWidget);
    // Must never leak physical components like "تيشيرت" / "ميدالية" on user reward card
    expect(find.textContaining('ميدالية'), findsNothing);
  });

  testWidgets('TeamGamificationPanel public view hides missions, sizes, and private award controls', (tester) async {
    await tester.pumpWidget(
      _wrapArabic(
        TeamGamificationPanel(
          profile: sampleProfile,
          team: sampleTeam,
          isPrivateView: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('جائزة خاصة من VSP'), findsNothing);
    expect(find.textContaining('المهام الشهرية المتدرجة'), findsNothing);
    expect(find.textContaining('جوائز بطل الشهر'), findsNothing);
    expect(find.textContaining('الخالدون'), findsOneWidget);
    expect(find.textContaining('أقوى فريق أسوان'), findsOneWidget);
  });

  testWidgets('showChallengeResultBreakdownDialog shows 50% repeat XP note and shield upgrade', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showChallengeResultBreakdownDialog(
                  context,
                  teamId: 'team-1',
                  summary: {
                    'official_season': true,
                    'home': {
                      'team_id': 'team-1',
                      'ranking_points_delta': 3,
                      'prev_rank': 4,
                      'new_rank': 2,
                      'base_xp': 40.0,
                      'mission_xp': 200.0,
                      'total_xp_earned': 240.0,
                      'is_repeat_opponent': true,
                      'missions_completed': ['ch_4'],
                      'shield_status': {
                        'shield_upgraded': true,
                        'current_shield': 'gold',
                      },
                    },
                  },
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('+3 نقطة'), findsOneWidget);
    expect(find.text('+240 XP'), findsOneWidget);
    expect(find.textContaining('50% من XP المباراة'), findsOneWidget);
    expect(find.textContaining('ترقية درع جديدة: الذهبي'), findsOneWidget);
  });
}
