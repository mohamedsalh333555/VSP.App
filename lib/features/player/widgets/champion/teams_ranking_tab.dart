import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/repositories/team_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/vsp_error_state.dart';
import '../../../../shared/widgets/vsp_fade_in_item.dart';
import 'champion_podium_components.dart';

class TeamsRankingTab extends StatelessWidget {
  final Stream<List<Team>> teamsStream;
  final String selectedLocation;
  final String selectedSport;
  final VoidCallback onRetry;

  const TeamsRankingTab({
    super.key,
    required this.teamsStream,
    required this.selectedLocation,
    required this.selectedSport,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Team>>(
      stream: teamsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }
        if (snapshot.hasError) {
          return VSPErrorState(
            customMessage: snapshot.error?.toString(),
            onRetry: onRetry,
          );
        }

        final List<Team> allTeams = snapshot.data ?? [];

        final teams = allTeams.where((team) {
          final matchesLocation = selectedLocation == 'All' ||
              team.governorate.toLowerCase() == selectedLocation.toLowerCase() ||
              EgyptGovernorates.resolveGoogleName(team.governorate) == selectedLocation ||
              (EgyptGovernorates.resolveGoogleName(team.governorate) != null &&
                  EgyptGovernorates.resolveGoogleName(team.governorate) ==
                      EgyptGovernorates.resolveGoogleName(selectedLocation));

          final matchesSport = team.sportType.toLowerCase() == selectedSport.toLowerCase();

          return matchesLocation && matchesSport;
        }).toList();

        if (teams.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                AppLocalizations.of(context)!.noTeamsInLoc(championTranslateItem(context, selectedLocation)),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
              ),
            ),
          );
        }

        // Sort by points desc
        teams.sort((a, b) => b.points.compareTo(a.points));

        final totalTeams = teams.length;
        final top3 = teams.take(3).toList();
        final rest = teams.skip(3).toList();

        if (teams.length < 3) {
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, VSPSpacing.md, 16, MediaQuery.of(context).padding.bottom + 24),
            physics: const BouncingScrollPhysics(),
            itemCount: teams.length,
            itemBuilder: (ctx, i) => VSPFadeInItem(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildRankListItem(context, teams[i], i + 1, totalTeams: totalTeams),
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
              // Premium Podium
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
                          logo: top3[1].logoUrl.isNotEmpty ? top3[1].logoUrl : top3[1].captainImageUrl,
                          points: top3[1].points,
                          badgeIcon: Iconsax.medal_star_copy,
                          borderColor: const Color(0xFFC0C0C0),
                          bgColor: VSPColors.surface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Rank 1 - Center (Gold)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 0,
                        child: ChampionPodiumItem(
                          rank: 1,
                          name: top3[0].name,
                          logo: top3[0].logoUrl.isNotEmpty ? top3[0].logoUrl : top3[0].captainImageUrl,
                          points: top3[0].points,
                          badgeIcon: Iconsax.crown_copy,
                          borderColor: VSPColors.accent,
                          bgColor: const Color(0xFF1E2614),
                          isCenter: true,
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
                          logo: top3[2].logoUrl.isNotEmpty ? top3[2].logoUrl : top3[2].captainImageUrl,
                          points: top3[2].points,
                          badgeIcon: Iconsax.award_copy,
                          borderColor: const Color(0xFFCD7F32),
                          bgColor: VSPColors.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Expanded Ranking List (#4, #5...)
              ...List.generate(rest.length, (index) {
                final team = rest[index];
                final rank = index + 4;
                return VSPFadeInItem(
                  index: index + 3,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildRankListItem(context, team, rank, totalTeams: totalTeams),
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

  Widget _buildRankListItem(BuildContext context, Team team, int rank, {bool isMyTeam = false, int totalTeams = 10}) {
    final initialLetter =
        team.name.trim().isNotEmpty ? team.name.trim().split(' ').last.substring(0, 1).toUpperCase() : 'T';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: isMyTeam
            ? Border.all(color: VSPColors.accent.withValues(alpha: 0.6))
            : Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
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

          // Team Logo / Initial Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VSPColors.surfaceAlt,
              border: Border.all(color: VSPColors.divider, width: 1),
            ),
            child: ClipOval(
              child: team.logoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: team.logoUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          ChampionInitialBadge(letter: initialLetter, accentColor: VSPColors.accent),
                    )
                  : ChampionInitialBadge(letter: initialLetter, accentColor: VSPColors.accent),
            ),
          ),
          const SizedBox(width: 12),

          // Team Name & Match Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        team.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FutureBuilder<bool>(
                      future: TeamRepository().has1v1Champion(team.id),
                      builder: (context, champSnap) {
                        if (champSnap.data == true) {
                          return Container(
                            margin: const EdgeInsetsDirectional.only(start: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF332608),
                              borderRadius: BorderRadius.circular(VSPRadius.full),
                              border: Border.all(color: const Color(0xFFEAB308), width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.crown_copy, size: 11, color: Color(0xFFFDE047)),
                                SizedBox(width: 3),
                                Text(
                                  'بطل 1v1',
                                  style: TextStyle(
                                      color: Color(0xFFFDE047), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context)!.teamStats(team.matchesPlayed, team.wins, team.draws, team.losses),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                ),
              ],
            ),
          ),
          // Points Column
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.divider.withValues(alpha: 0.4)),
            ),
            child: Text(
              AppLocalizations.of(context)!.pointsCount(team.points),
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
