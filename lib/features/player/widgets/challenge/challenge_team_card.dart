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
  final bool isLoadingH2H;
  final Map<String, int>? h2hStats;
  final ({bool isRepeat, int seasonMatches, num winXp, num drawXp, num lossXp})? repeatStatus;
  final VoidCallback onTap;

  const ChallengeTeamCard({
    super.key,
    required this.team,
    required this.isSelected,
    required this.isLoadingH2H,
    this.h2hStats,
    this.repeatStatus,
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
              ? VSPColors.surfaceAlt
              : VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(
            color: isSelected ? VSPColors.textPrimary : VSPColors.divider,
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
                  const Icon(Iconsax.tick_circle_copy, color: VSPColors.info)
                else
                  Icon(
                    Iconsax.tick_circle_copy,
                    color: VSPColors.textSecondary.withValues(alpha: 0.3),
                  ),
              ],
            ),
            if (isSelected) ...[
              if (repeatStatus != null) ...[
                const SizedBox(height: 12),
                _buildRepeatXpNotice(context, repeatStatus!),
              ],
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
                        color: VSPColors.info,
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

  Widget _buildRepeatXpNotice(
    BuildContext context,
    ({bool isRepeat, int seasonMatches, num winXp, num drawXp, num lossXp}) status,
  ) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isRepeat = status.isRepeat;
    final color = isRepeat ? VSPColors.warning : VSPColors.info;
    String fmt(num n) => n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(VSPRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRepeat ? Iconsax.info_circle_copy : Iconsax.flash_1_copy,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isRepeat
                  ? (isArabic
                      ? 'تواجهتَ مع هذا الفريق من قبل هذا الموسم (${status.seasonMatches} مرة): نقاط الترتيب الشهري تبقى كاملة 100% (3/1/0)، أما XP المباراة فتُحتسب بالنصف (${fmt(status.winXp)} فوز / ${fmt(status.drawXp)} تعادل / ${fmt(status.lossXp)} خسارة).'
                      : 'Repeat opponent this season (${status.seasonMatches}x): Monthly Ranking points remain 100% (3/1/0), while match XP is 50% (${fmt(status.winXp)}W / ${fmt(status.drawXp)}D / ${fmt(status.lossXp)}L).')
                  : (isArabic
                      ? 'منافس جديد في هذا الموسم! نقاط الترتيب (3/1/0) وXP كاملة 100% (${fmt(status.winXp)} فوز / ${fmt(status.drawXp)} تعادل / ${fmt(status.lossXp)} خسارة).'
                      : 'New opponent this season! Full 100% Monthly Ranking (3/1/0) & Match XP (${fmt(status.winXp)}W / ${fmt(status.drawXp)}D / ${fmt(status.lossXp)}L).'),
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
            _buildH2HStatItem(l10n.yourWins, wins, VSPColors.info),
            _buildH2HStatItem(l10n.draws, draws, VSPColors.textSecondary),
            _buildH2HStatItem(l10n.theirWins, opposingWins, VSPColors.error),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: VSPColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(VSPRadius.sm),
          ),
          child: Text(
            hypeMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: VSPColors.info,
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
