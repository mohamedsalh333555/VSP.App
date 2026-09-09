import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// One animated matchup row in the live draw room dialog.
///
/// Shows both team names when [isRevealed] is true; otherwise shows a
/// "Pending draw…" placeholder at reduced opacity.
class DrawRoomMatchupTile extends StatelessWidget {
  final Map<String, String> matchup;
  final bool isRevealed;
  final bool isArabic;

  const DrawRoomMatchupTile({
    super.key,
    required this.matchup,
    required this.isRevealed,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final pendingLabel = isArabic ? 'قيد السحب...' : 'Pending draw...';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isRevealed ? 1.0 : 0.2,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isRevealed
              ? VSPColors.accent.withValues(alpha: 0.12)
              : VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: isRevealed ? VSPColors.accent : VSPColors.divider,
            width: isRevealed ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isRevealed ? matchup['home']! : pendingLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isRevealed ? Colors.white : VSPColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'VS',
                style: TextStyle(
                    color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                isRevealed ? matchup['away']! : pendingLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isRevealed ? Colors.white : VSPColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
