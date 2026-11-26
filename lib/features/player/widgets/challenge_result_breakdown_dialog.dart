import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models/team_gamification_models.dart';
import '../../../shared/widgets/shields/vsp_shield_badge.dart';
import '../screens/player_home_screen.dart';

/// Displays the authoritative server breakdown of Ranking Points, Season XP,
/// Repeat Opponent weighting, Monthly Missions, and Shield Upgrades after
/// a challenge result is confirmed by both captains.
Future<void> showChallengeResultBreakdownDialog(
  BuildContext context, {
  required Map<String, dynamic> summary,
  required String teamId,
}) {
  final home = summary['home'] is Map
      ? Map<String, dynamic>.from(summary['home'] as Map)
      : const <String, dynamic>{};
  final away = summary['away'] is Map
      ? Map<String, dynamic>.from(summary['away'] as Map)
      : const <String, dynamic>{};

  final mine = home['team_id']?.toString() == teamId
      ? home
      : (away['team_id']?.toString() == teamId ? away : home);

  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final isPreLaunch =
      mine['pre_launch_test'] == true || summary['official_season'] == false;
  final rankDelta = (mine['ranking_points_delta'] as num?)?.toInt() ?? 0;
  final prevRank = (mine['prev_rank'] as num?)?.toInt();
  final newRank = (mine['new_rank'] as num?)?.toInt();
  final baseXp = (mine['base_xp'] as num?)?.toDouble() ?? 0;
  final missionXp = (mine['mission_xp'] as num?)?.toDouble() ?? 0;
  final totalXp = (mine['total_xp_earned'] as num?)?.toDouble() ?? (baseXp + missionXp);
  final isRepeat = mine['is_repeat_opponent'] == true;
  final missions = List<String>.from(mine['missions_completed'] as List? ?? const []);
  final shieldMap = mine['shield_status'] is Map
      ? Map<String, dynamic>.from(mine['shield_status'] as Map)
      : const <String, dynamic>{};
  final shieldUpgraded = shieldMap['shield_upgraded'] == true;
  final currentShield = TeamShieldTier.fromCode(shieldMap['current_shield']?.toString());

  String fmtNum(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: VSPColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        side: BorderSide(color: VSPColors.accent.withValues(alpha: 0.35)),
      ),
      title: Row(
        children: [
          const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic ? 'تم اعتماد نتيجة التحدي' : 'Challenge Confirmed',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isPreLaunch)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: VSPColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.warning.withValues(alpha: 0.4)),
                ),
                child: Text(
                  isArabic
                      ? 'فترة تجريبية قبل انطلاق الموسم الرسمي — لا تُحتسب نقاط أو جوائز رسمية بعد.'
                      : 'Pre-launch test period — no official XP or rewards are granted yet.',
                  style: const TextStyle(color: VSPColors.warning, fontSize: 12),
                ),
              )
            else ...[
              // Ranking Points row
              _BreakdownMetricTile(
                icon: Iconsax.ranking_copy,
                title: isArabic ? 'نقاط الترتيب الشهري (المحافظة)' : 'Monthly Governorate Ranking',
                value: '+$rankDelta ${isArabic ? 'نقطة' : 'pts'}',
                subtitle: newRank != null
                    ? (prevRank != null
                        ? (isArabic ? 'المركز: #$prevRank → #$newRank' : 'Rank: #$prevRank → #$newRank')
                        : (isArabic ? 'المركز الحالي: #$newRank' : 'Current Rank: #$newRank'))
                    : null,
                accentColor: VSPColors.accent,
              ),
              const SizedBox(height: 10),
              // Season XP row
              _BreakdownMetricTile(
                icon: Iconsax.flash_1_copy,
                title: isArabic ? 'نقاط الخبرة السنوية (Season XP)' : 'Annual Season XP',
                value: '+${fmtNum(totalXp)} XP',
                subtitle: missionXp > 0
                    ? (isArabic
                        ? 'المباراة: +${fmtNum(baseXp)} • المهام: +${fmtNum(missionXp)}'
                        : 'Match: +${fmtNum(baseXp)} • Missions: +${fmtNum(missionXp)}')
                    : (isArabic
                        ? 'نقاط المباراة: +${fmtNum(baseXp)} XP'
                        : 'Match XP: +${fmtNum(baseXp)} XP'),
                accentColor: VSPColors.info,
              ),
              if (isRepeat) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: VSPColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.warning.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    isArabic
                        ? 'ملاحظة: تمت مواجهة هذا الخصم من قبل في نفس الموسم، لذلك تم احتساب 50% من XP المباراة مع بقاء نقاط الترتيب 100%.'
                        : 'Note: Repeat opponent in this season — match XP is 50% while monthly ranking points remain 100%.',
                    style: const TextStyle(
                      color: VSPColors.warning,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (missions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'مهام شهرية مكتملة' : 'Monthly Missions Completed',
                        style: const TextStyle(
                          color: VSPColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        missions.map((m) => _localizeMissionCode(m, isArabic)).join(' • '),
                        style: const TextStyle(
                          color: VSPColors.textPrimary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (shieldUpgraded && currentShield != TeamShieldTier.none) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: currentShield.primaryColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(VSPRadius.lg),
                    border: Border.all(
                      color: currentShield.primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      VspShieldBadge(tier: currentShield, size: 46),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'ترقية درع جديدة: ${currentShield.label(true)}'
                                  : 'New Shield Unlocked: ${currentShield.label(false)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            if (currentShield == TeamShieldTier.immortal)
                              Text(
                                isArabic
                                    ? 'تأهل فريقك لاستحقاق جائزة خاصة من VSP!'
                                    : 'Your team qualified for a Special VSP Reward!',
                                style: const TextStyle(
                                  color: VSPColors.accent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            navigateToTeamsStandings(context);
          },
          child: Text(isArabic ? 'جدول الترتيب' : 'Standings'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: VSPColors.accent,
            foregroundColor: Colors.black,
          ),
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            isArabic ? 'حسناً' : 'Done',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

String _localizeMissionCode(String code, bool isArabic) {
  switch (code) {
    case 'ch_4':
      return isArabic ? '4 تحديات' : '4 Challenges';
    case 'ch_6':
      return isArabic ? '6 تحديات' : '6 Challenges';
    case 'ch_8':
      return isArabic ? '8 تحديات' : '8 Challenges';
    case 'ch_10':
      return isArabic ? '10 تحديات' : '10 Challenges';
    case 'ch_12':
      return isArabic ? '12 تحدياً' : '12 Challenges';
    case 'win_2':
      return isArabic ? 'فوزان' : '2 Wins';
    case 'win_3':
      return isArabic ? '3 انتصارات' : '3 Wins';
    case 'win_4':
      return isArabic ? '4 انتصارات' : '4 Wins';
    case 'win_5':
      return isArabic ? '5 انتصارات' : '5 Wins';
    case 'win_6':
      return isArabic ? '6 انتصارات' : '6 Wins';
    case 'opp_2':
      return isArabic ? 'مواجهتان لخصوم جدد' : '2 Unique Opponents';
    case 'opp_3':
      return isArabic ? '3 خصوم مختلفين' : '3 Unique Opponents';
    case 'opp_4':
      return isArabic ? '4 خصوم مختلفين' : '4 Unique Opponents';
    case 'opp_5':
      return isArabic ? '5 خصوم مختلفين' : '5 Unique Opponents';
    case 'opp_6':
      return isArabic ? '6 خصوم مختلفين' : '6 Unique Opponents';
    case 'tourn_1':
      return isArabic ? 'مشاركة في بطولة' : 'Tournament Participation';
    default:
      return code;
  }
}

class _BreakdownMetricTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final Color accentColor;

  const _BreakdownMetricTile({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: VSPColors.textPrimary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
