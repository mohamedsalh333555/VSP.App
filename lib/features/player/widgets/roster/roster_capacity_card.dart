import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Card showing current team lineup capacity progress vs tournament min and max constraints.
class RosterCapacityCard extends StatelessWidget {
  final int currentTotal;
  final int minPlayers;
  final int maxPlayers;
  final bool isArabic;

  const RosterCapacityCard({
    super.key,
    required this.currentTotal,
    required this.minPlayers,
    required this.maxPlayers,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final progressRatio = maxPlayers > 0 ? (currentTotal / maxPlayers).clamp(0.0, 1.0) : 0.0;
    final bool isValid = currentTotal >= minPlayers && currentTotal <= maxPlayers;

    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'إجمالي عدد التشكيلة' : 'Total Roster',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '$currentTotal / $maxPlayers',
                style: TextStyle(
                  color: isValid ? VSPColors.accent : VSPColors.error,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 8,
              backgroundColor: VSPColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(
                currentTotal >= minPlayers ? VSPColors.accent : VSPColors.error,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'الحد الأدنى: $minPlayers لاعبين' : 'Min: $minPlayers players',
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                isArabic ? 'الحد الأقصى: $maxPlayers لاعبين' : 'Max: $maxPlayers players',
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
