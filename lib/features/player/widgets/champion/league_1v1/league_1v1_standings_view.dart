import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../../data/models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/vsp_error_state.dart';
import '../../../../../shared/widgets/vsp_fade_in_item.dart';
import '../champion_podium_components.dart';

/// Standings phase view displaying the championship podium (Top 3) and full ranking list for 1v1 tournaments.
class League1v1StandingsView extends StatefulWidget {
  final Stream<List<VSP1v1Player>> standingsStream;
  final VoidCallback onRetry;

  const League1v1StandingsView({
    super.key,
    required this.standingsStream,
    required this.onRetry,
  });

  @override
  State<League1v1StandingsView> createState() => _League1v1StandingsViewState();
}

class _League1v1StandingsViewState extends State<League1v1StandingsView> {
  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return StreamBuilder<List<VSP1v1Player>>(
      stream: widget.standingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }
        if (snapshot.hasError) {
          return VSPErrorState(
            customMessage: snapshot.error?.toString(),
            onRetry: () => setState(() {}),
          );
        }
        final players = snapshot.data ?? [];
        if (players.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Iconsax.cup_copy, size: 38, color: VSPColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noOneVsOneRanked,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        final top3 = players.take(3).toList();
        final rest = players.skip(3).toList();

        if (players.length < 3) {
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, VSPSpacing.md, 16, MediaQuery.of(context).padding.bottom + 24),
            physics: const BouncingScrollPhysics(),
            itemCount: players.length,
            itemBuilder: (ctx, i) => VSPFadeInItem(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: League1v1RankListItem(
                  player: players[i],
                  rank: i + 1,
                  isArabic: isArabic,
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 12),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Premium 1v1 Podium
              SizedBox(
                height: 290,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Rank 2 - Left (Silver)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 1,
                        child: ChampionPodiumItem(
                          rank: 2,
                          name: top3[1].name,
                          logo: top3[1].avatarUrl,
                          points: top3[1].totalPoints,
                          badgeIcon: Iconsax.medal_star_copy,
                          borderColor: VSPColors.medalSilver,
                          bgColor: VSPColors.surface,
                          pointsLabel: isArabic ? 'نقطة' : 'PTS',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Rank 1 - Center (Gold Champion)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 0,
                        child: ChampionPodiumItem(
                          rank: 1,
                          name: top3[0].name,
                          logo: top3[0].avatarUrl,
                          points: top3[0].totalPoints,
                          badgeIcon: Iconsax.crown_copy,
                          borderColor: VSPColors.accent,
                          bgColor: VSPColors.cardDarkGreen,
                          isCenter: true,
                          pointsLabel: isArabic ? 'نقطة' : 'PTS',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Rank 3 - Right (Bronze)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 2,
                        child: ChampionPodiumItem(
                          rank: 3,
                          name: top3[2].name,
                          logo: top3[2].avatarUrl,
                          points: top3[2].totalPoints,
                          badgeIcon: Iconsax.award_copy,
                          borderColor: VSPColors.medalBronze,
                          bgColor: VSPColors.surface,
                          pointsLabel: isArabic ? 'نقطة' : 'PTS',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Expanded Ranking List (#4, #5...)
              ...List.generate(rest.length, (index) {
                final player = rest[index];
                final rank = index + 4;
                return VSPFadeInItem(
                  index: index + 3,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: League1v1RankListItem(
                      player: player,
                      rank: rank,
                      isArabic: isArabic,
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

/// Item representing an individual player rank with metrics and points.
class League1v1RankListItem extends StatelessWidget {
  final VSP1v1Player player;
  final int rank;
  final bool isArabic;

  const League1v1RankListItem({
    super.key,
    required this.player,
    required this.rank,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final initialLetter =
        player.name.trim().isNotEmpty ? player.name.trim().split(' ').last.substring(0, 1).toUpperCase() : 'P';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Rank Number
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: rank <= 3 ? VSPColors.accent : VSPColors.textSecondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
            ),
          ),

          // Player Avatar / Initial
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VSPColors.surfaceAlt,
              border: Border.all(color: VSPColors.divider, width: 1),
            ),
            child: ClipOval(
              child: player.avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: player.avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          ChampionInitialBadge(letter: initialLetter, accentColor: VSPColors.accent),
                    )
                  : ChampionInitialBadge(letter: initialLetter, accentColor: VSPColors.accent),
            ),
          ),
          const SizedBox(width: 12),

          // Player Name & Breakdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isArabic
                      ? 'قطع كرات: ${player.tackles}  •  أهداف: ${player.goals}  •  مهارات: ${player.skillPoints}'
                      : 'Tackles: ${player.tackles}  •  Goals: ${player.goals}  •  Skills: ${player.skillPoints}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VSPColors.textSecondary,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),

          // Total Points Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.divider.withValues(alpha: 0.4)),
            ),
            child: Text(
              '${player.totalPoints} ${isArabic ? "نقطة" : "PTS"}',
              style: const TextStyle(
                color: VSPColors.accent,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
