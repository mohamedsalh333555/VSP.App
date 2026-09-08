import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';

class TeamProfileAchievementsSection extends StatelessWidget {
  final Team team;

  const TeamProfileAchievementsSection({
    super.key,
    required this.team,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final badges = [
      {'id': 'explorer', 'name': 'Explorer', 'icon': Iconsax.discover_copy, 'desc': 'Play against 5 different teams'},
      {'id': 'gladiator', 'name': 'Gladiator', 'icon': Iconsax.security_safe_copy, 'desc': 'Played 10+ matches'},
      {'id': 'streak_3', 'name': 'Streak 3', 'icon': Iconsax.flash_1_copy, 'desc': 'Won 3 matches in a row'},
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
                      color: isUnlocked
                          ? VSPColors.accent.withValues(alpha: 0.1)
                          : VSPColors.surfaceAlt.withValues(alpha: 0.5),
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
