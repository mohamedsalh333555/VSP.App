import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Renders the full interactive bracket canvas inside
/// [showTournamentBracketPreviewDialog].
///
/// [rounds] is the list of bracket rounds produced by
/// [TournamentBracketBuilder.buildRounds]. [numOpeningMatches] is needed to
/// compute round-label text.
class BracketPreviewCanvas extends StatelessWidget {
  final List<List<Map<String, String>>> rounds;
  final int numOpeningMatches;

  const BracketPreviewCanvas({
    super.key,
    required this.rounds,
    required this.numOpeningMatches,
  });

  @override
  Widget build(BuildContext context) {
    final int maxMatchesInFirstRound = rounds.first.length;
    final double totalBracketHeight =
        (maxMatchesInFirstRound * 84.0).clamp(450.0, 1600.0);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rounds.asMap().entries.map((entry) {
            final int roundIdx = entry.key;
            final List<Map<String, String>> roundMatches = entry.value;
            final int matchCount = roundMatches.length;
            final double slotHeight = totalBracketHeight / matchCount;

            final String roundLabel = roundIdx == 0 && numOpeningMatches > 0
                ? 'جولة تمهيدية'
                : (roundIdx == rounds.length - 1
                    ? 'النهائي'
                    : 'جولة ${numOpeningMatches > 0 ? roundIdx : roundIdx + 1}');

            final Widget roundColumn = SizedBox(
              width: 165,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Round header
                  Container(
                    height: 32,
                    alignment: Alignment.center,
                    child: Text(
                      roundLabel,
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Match cards
                  SizedBox(
                    height: totalBracketHeight,
                    child: Column(
                      children: roundMatches.map((m) {
                        return SizedBox(
                          height: slotHeight,
                          child: Center(
                            child: _BracketMatchCard(
                              home: m['home']!,
                              away: m['away']!,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );

            final isRtl = Directionality.of(context) == TextDirection.rtl;

            return Row(
              children: [
                roundColumn,
                SizedBox(
                  height: totalBracketHeight + 32,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        isRtl ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_1_copy,
                        color: VSPColors.accent,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),

          // Champion card at end
          SizedBox(
            width: 155,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),
                SizedBox(
                  height: totalBracketHeight,
                  child: Center(
                    child: Container(
                      width: 145,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(VSPRadius.lg),
                        border: Border.all(color: VSPColors.accent, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: VSPColors.accent.withValues(alpha: 0.2),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 36),
                          SizedBox(height: 8),
                          Text(
                            'البطل',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: VSPColors.accent,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'الفائز بالنهائي',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
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

/// A single match card rendered inside a bracket round column.
class _BracketMatchCard extends StatelessWidget {
  final String home;
  final String away;

  const _BracketMatchCard({required this.home, required this.away});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            home,
            style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 8, color: Colors.white12),
          Text(
            away,
            style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
