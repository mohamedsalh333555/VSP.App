import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Banner displaying the champion team at the top of the final round.
class TournamentChampionBanner extends StatelessWidget {
  final String championName;

  const TournamentChampionBanner({
    super.key,
    required this.championName,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent, width: 2),
        boxShadow: [
          BoxShadow(color: VSPColors.accent.withValues(alpha: 0.25), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'بطل البطولة النهائي' : 'Final Tournament Champion',
                  style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  championName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
