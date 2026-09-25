import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/team_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/vsp_error_state.dart';
import '../../../../shared/widgets/vsp_fade_in_item.dart';
import 'champion_podium_components.dart';

class TeamsRankingTab extends StatefulWidget {
  final Stream<List<Team>>? teamsStream;
  final String selectedLocation;
  final String selectedSport;
  final VoidCallback onRetry;
  final TeamRepository? teamRepository;

  const TeamsRankingTab({
    super.key,
    this.teamsStream,
    required this.selectedLocation,
    required this.selectedSport,
    required this.onRetry,
    this.teamRepository,
  });

  @override
  State<TeamsRankingTab> createState() => _TeamsRankingTabState();
}

class _TeamsRankingTabState extends State<TeamsRankingTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late Stream<List<Team>> _stream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    if (widget.teamsStream != null) {
      _stream = widget.teamsStream!;
    } else {
      _stream = (widget.teamRepository ?? TeamRepository()).getTeams();
    }
  }

  @override
  void didUpdateWidget(covariant TeamsRankingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.teamsStream != null && widget.teamsStream != oldWidget.teamsStream) {
      _stream = widget.teamsStream!;
    } else if (widget.teamsStream == null &&
        oldWidget.selectedLocation != widget.selectedLocation) {
      setState(() {
        _initStream();
      });
    }
  }

  void _handleRetry() {
    setState(() {
      _initStream();
    });
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<Team>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }
        if (snapshot.hasError) {
          return VSPErrorState(
            customMessage: snapshot.error?.toString(),
            onRetry: _handleRetry,
          );
        }

        final List<Team> allTeams = snapshot.data ?? [];

        final teams = allTeams.where((team) {
          final matchesLocation = widget.selectedLocation == 'All' ||
              team.governorate.toLowerCase() == widget.selectedLocation.toLowerCase() ||
              EgyptGovernorates.resolveGoogleName(team.governorate) == widget.selectedLocation ||
              (EgyptGovernorates.resolveGoogleName(team.governorate) != null &&
                  EgyptGovernorates.resolveGoogleName(team.governorate) ==
                      EgyptGovernorates.resolveGoogleName(widget.selectedLocation));

          final matchesSport = team.sportType.toLowerCase() == widget.selectedSport.toLowerCase();

          return matchesLocation && matchesSport;
        }).toList();

        if (teams.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                AppLocalizations.of(context)!.noTeamsInLoc(championTranslateItem(context, widget.selectedLocation)),
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

        final auth = Provider.of<AuthProvider>(context, listen: false);
        final currentUid = auth.currentUser?.uid;

        bool isUserTeam(Team team) {
          if (currentUid == null) return false;
          return team.captainId == currentUid || team.memberUids.contains(currentUid);
        }

        final myTeamIndex = teams.indexWhere((t) => isUserTeam(t));
        final myTeam = myTeamIndex != -1 ? teams[myTeamIndex] : null;
        final myTeamRank = myTeamIndex != -1 ? myTeamIndex + 1 : null;

        Widget content;

        if (teams.length < 3) {
          content = ListView.builder(
            padding: EdgeInsets.fromLTRB(16, VSPSpacing.md, 16, MediaQuery.of(context).padding.bottom + (myTeam != null ? 80 : 24)),
            physics: const BouncingScrollPhysics(),
            itemCount: teams.length,
            itemBuilder: (ctx, i) => VSPFadeInItem(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildRankListItem(context, teams[i], i + 1, isMyTeam: isUserTeam(teams[i]), totalTeams: totalTeams),
              ),
            ),
          );
        } else {
          content = SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 12).copyWith(
              bottom: (myTeam != null ? 90.0 : 40.0),
            ),
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
                            borderColor: VSPColors.medalSilver,
                            bgColor: VSPColors.surface,
                            isMyTeam: isUserTeam(top3[1]),
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
                            bgColor: VSPColors.surfaceAlt,
                            isCenter: true,
                            isMyTeam: isUserTeam(top3[0]),
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
                            borderColor: VSPColors.medalBronze,
                            bgColor: VSPColors.surface,
                            isMyTeam: isUserTeam(top3[2]),
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
                      child: _buildRankListItem(
                        context,
                        team,
                        rank,
                        isMyTeam: isUserTeam(team),
                        totalTeams: totalTeams,
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 20),
              ],
            ),
          );
        }

        if (myTeam != null && myTeamRank != null) {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          return Stack(
            children: [
              content,
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(VSPRadius.lg),
                    border: Border.all(color: VSPColors.accent, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: VSPColors.accent.withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: VSPColors.accent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isArabic ? 'موقع فريقك في الترتيب العام' : 'Your Team Standing',
                              style: TextStyle(
                                color: VSPColors.textSecondary.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${myTeam.name} • ${isArabic ? 'المركز #$myTeamRank' : 'Rank #$myTeamRank'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: VSPColors.accent,
                          borderRadius: BorderRadius.circular(VSPRadius.full),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.pointsCount(myTeam.points),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return content;
      },
    );
  }

  Widget _buildRankListItem(BuildContext context, Team team, int rank, {bool isMyTeam = false, int totalTeams = 10}) {
    final initialLetter =
        team.name.trim().isNotEmpty ? team.name.trim().split(' ').last.substring(0, 1).toUpperCase() : 'T';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMyTeam ? VSPColors.accent.withValues(alpha: 0.12) : VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: isMyTeam
            ? Border.all(color: VSPColors.accent, width: 1.5)
            : Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
        boxShadow: isMyTeam
            ? [
                BoxShadow(
                  color: VSPColors.accent.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
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
                              color: isMyTeam ? VSPColors.accent : VSPColors.textPrimary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMyTeam)
                      Container(
                        margin: const EdgeInsetsDirectional.only(start: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: VSPColors.accent,
                          borderRadius: BorderRadius.circular(VSPRadius.full),
                        ),
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'ar' ? 'فريقك' : 'Your Team',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
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
                              color: VSPColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(VSPRadius.full),
                              border: Border.all(color: VSPColors.warning, width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.crown_copy, size: 11, color: VSPColors.warning),
                                SizedBox(width: 3),
                                Text(
                                  'بطل 1v1',
                                  style: TextStyle(
                                      color: VSPColors.warning, fontSize: 9, fontWeight: FontWeight.bold),
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
