import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';
import '../../../../data/models/team_gamification_models.dart';
import '../../../../shared/widgets/shields/vsp_shield_badge.dart';

class TeamProfileHeroHeader extends StatelessWidget {
  final Team team;
  final TeamShieldTier? currentShield;
  final int? monthlyRank;

  const TeamProfileHeroHeader({
    super.key,
    required this.team,
    this.currentShield,
    this.monthlyRank,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final effectiveShield = currentShield ?? TeamShieldTier.fromCode(team.currentShield);
    return Center(
      child: Column(
        children: [
          ShimmerImage(
            imageUrl: team.logoUrl,
            width: 100,
            height: 100,
            borderRadius: 50,
            errorWidget: const CircleAvatar(
              radius: 50,
              backgroundColor: VSPColors.surface,
              child: Icon(Iconsax.people_copy, color: VSPColors.textSecondary, size: 40),
            ),
          ),
          const SizedBox(height: VSPSpacing.md),
          Text(
            team.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: VSPSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Iconsax.location_copy, color: VSPColors.textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(
                '${team.governorate} • ${team.sportType}',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: effectiveShield.primaryColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: effectiveShield.primaryColor.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VspShieldBadge(tier: effectiveShield, size: 22),
                const SizedBox(width: 6),
                Text(
                  effectiveShield.label(isArabic),
                  style: TextStyle(
                    color: effectiveShield.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (monthlyRank != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? '• الترتيب الشهري #$monthlyRank' : '• Monthly #$monthlyRank',
                    style: const TextStyle(
                      color: VSPColors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
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
