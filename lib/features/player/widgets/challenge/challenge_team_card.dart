import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../services/challenge_team_service.dart';

/// Interactive Team Card widget for the challenge opponent selection screen.
/// Displays team captain avatar, champion status badge, selection state,
/// and expandable Head-to-Head (H2H) competitive statistics.
class ChallengeTeamCard extends StatelessWidget {
  final Team team;
  final bool isSelected;
  final bool hasChampion;
  final bool isLoadingH2H;
  final Map<String, int>? h2hStats;
  final VoidCallback onTap;

  const ChallengeTeamCard({
    super.key,
    required this.team,
    required this.isSelected,
    required this.hasChampion,
    required this.isLoadingH2H,
    this.h2hStats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(VSPSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? VSPColors.accent.withValues(alpha: 0.05)
              : VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(
            color: isSelected ? VSPColors.accent : VSPColors.divider,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ShimmerImage(
                  imageUrl: team.captainImageUrl,
                  width: 50,
                  height: 50,
                  borderRadius: VSPRadius.full,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              team.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (hasChampion) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: VSPColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: VSPColors.warning, width: 1),
                              ),
                              child: const Text(
                                ' يضم بطل 1 ضد 1',
                                style: TextStyle(
                                  color: VSPColors.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.matchesPlayedCount(team.matchesPlayed),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: VSPColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent)
                else
                  Icon(
                    Iconsax.tick_circle_copy,
                    color: VSPColors.textSecondary.withValues(alpha: 0.3),
                  ),
              ],
            ),
            if (isSelected) ...[
              const Divider(color: VSPColors.divider, height: 32),
              if (isLoadingH2H)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: VSPColors.accent,
                      ),
                    ),
                  ),
                )
              else if (h2hStats != null && h2hStats!['totalMatches']! > 0)
                _buildH2HContent(context, l10n)
              else if (h2hStats != null)
                Text(
                  l10n.firstTimePlaying,
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildH2HContent(BuildContext context, AppLocalizations l10n) {
    final wins = h2hStats!['teamAWins']!;
    final opposingWins = h2hStats!['teamBWins']!;
    final draws = h2hStats!['draws']!;

    final hypeType = ChallengeTeamService.evaluateH2HHype(
      yourWins: wins,
      theirWins: opposingWins,
    );

    final String hypeMessage;
    switch (hypeType) {
      case H2HHypeType.youDominate:
        hypeMessage = l10n.youDominate;
        break;
      case H2HHypeType.timeForRevenge:
        hypeMessage = l10n.timeForRevenge;
        break;
      case H2HHypeType.seriesTied:
        hypeMessage = l10n.seriesTied;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.headToHeadHistory,
          style: const TextStyle(
            color: VSPColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildH2HStatItem(l10n.yourWins, wins, VSPColors.accent),
            _buildH2HStatItem(l10n.draws, draws, VSPColors.textSecondary),
            _buildH2HStatItem(l10n.theirWins, opposingWins, VSPColors.error),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: VSPColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(VSPRadius.sm),
          ),
          child: Text(
            hypeMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: VSPColors.accent,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildH2HStatItem(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: VSPColors.textSecondary.withValues(alpha: 0.6),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
