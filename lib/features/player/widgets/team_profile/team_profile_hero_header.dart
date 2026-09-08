import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';

class TeamProfileHeroHeader extends StatelessWidget {
  final Team team;
  final bool has1v1Champion;

  const TeamProfileHeroHeader({
    super.key,
    required this.team,
    required this.has1v1Champion,
  });

  @override
  Widget build(BuildContext context) {
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
              const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 14),
              const SizedBox(width: 4),
              Text(
                '${team.governorate} • ${team.sportType}',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              team.rankTitle,
              style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          if (has1v1Champion) ...[
            const SizedBox(height: VSPSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: VSPColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: VSPColors.warning, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: VSPColors.warning.withValues(alpha: 0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Text(
                ' يضم بطل 1 ضد 1',
                style: TextStyle(
                  color: VSPColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
