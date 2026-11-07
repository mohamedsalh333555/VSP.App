import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../my_team/team_achievement_badges.dart';
import '../my_team/team_achievement_summary.dart';

class TeamProfileAchievementsSection extends StatelessWidget {
  final Team team;
  /// Only provide verified results loaded from the authoritative data source.
  final TeamAchievementSummary? verifiedSummary;

  const TeamProfileAchievementsSection({
    super.key,
    required this.team,
    this.verifiedSummary,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final badges = [
      {'id': 'explorer', 'name': isArabic ? 'المستكشف' : 'Explorer', 'icon': Iconsax.discover_copy, 'desc': isArabic ? 'مواجهة 5 فرق مختلفة' : 'Play against 5 different teams'},
      {'id': 'gladiator', 'name': isArabic ? 'المحارب' : 'Gladiator', 'icon': Iconsax.security_safe_copy, 'desc': isArabic ? 'خوض 10 مباريات أو أكثر' : 'Played 10+ matches'},
      {'id': 'streak_3', 'name': isArabic ? '3 انتصارات متتالية' : 'Streak 3', 'icon': Iconsax.flash_1_copy, 'desc': isArabic ? 'الفوز في 3 مباريات متتالية' : 'Won 3 matches in a row'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.teamAchievements, style: Theme.of(context).textTheme.titleLarge),
            if (team.currentWinningStreak > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VSPColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: VSPColors.warning.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.flash_1_copy, color: VSPColors.warning, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      l10n.winStreak(team.currentWinningStreak),
                      style: const TextStyle(color: VSPColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (verifiedSummary != null) ...[
          const SizedBox(height: VSPSpacing.md),
          TeamAchievementBadges(summary: verifiedSummary!),
        ],
        const SizedBox(height: VSPSpacing.md),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              final badge = badges[index];
              final isUnlocked = team.unlockedBadges.contains(badge['id']);
              return Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: VSPColors.iconBadgeBg,
                      border: Border.all(
                        color: isUnlocked ? VSPColors.accent : VSPColors.divider,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      badge['icon'] as IconData,
                      color: isUnlocked
                          ? VSPColors.accent
                          : VSPColors.textSecondary.withValues(alpha: 0.3),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: VSPSpacing.sm),
                  Text(
                    badge['name'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isUnlocked ? VSPColors.textPrimary : VSPColors.textSecondary.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
