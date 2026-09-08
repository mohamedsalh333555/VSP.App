import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class CheckoutSquadRequirementCard extends StatelessWidget {
  final int totalCount;
  final int minPlayers;
  final int maxPlayers;
  final bool isSelectionValid;

  const CheckoutSquadRequirementCard({
    super.key,
    required this.totalCount,
    required this.minPlayers,
    required this.maxPlayers,
    required this.isSelectionValid,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSelectionValid
            ? VSPColors.accent.withValues(alpha: 0.08)
            : VSPColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: isSelectionValid
              ? VSPColors.accent.withValues(alpha: 0.3)
              : VSPColors.warning.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelectionValid
                  ? VSPColors.accent.withValues(alpha: 0.15)
                  : VSPColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.people_copy,
              color: isSelectionValid ? VSPColors.accent : VSPColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isArabic ? 'تشكيلة الفريق' : 'Team Roster',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelectionValid ? VSPColors.accent : VSPColors.warning,
                        borderRadius: BorderRadius.circular(VSPRadius.full),
                      ),
                      child: Text(
                        isArabic ? '$totalCount لاعبين' : '$totalCount Players',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  minPlayers == maxPlayers
                      ? (isArabic ? 'المطلوب: $minPlayers لاعبين بالضبط' : 'Required: Exactly $minPlayers players')
                      : (isArabic ? 'المطلوب: من $minPlayers إلى $maxPlayers لاعبين' : 'Required: $minPlayers to $maxPlayers players'),
                  style: TextStyle(
                    color: isSelectionValid ? VSPColors.textSecondary : VSPColors.warning,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
