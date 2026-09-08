import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

class CheckoutChampionshipHeader extends StatelessWidget {
  final Championship championship;
  final Team team;

  const CheckoutChampionshipHeader({
    super.key,
    required this.championship,
    required this.team,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(VSPRadius.lg),
            ),
            child: const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  championship.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Iconsax.location_copy, color: VSPColors.textSecondary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      championship.governorate,
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Iconsax.people_copy, color: VSPColors.textSecondary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      team.name,
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
