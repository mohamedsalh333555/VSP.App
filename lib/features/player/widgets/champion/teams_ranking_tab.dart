import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/gamification_repository.dart';
import '../../../../core/repositories/team_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models/team_gamification_models.dart';
import '../../../../shared/widgets/shields/vsp_shield_badge.dart';
import '../../../../shared/widgets/vsp_error_state.dart';
import '../../../../shared/widgets/vsp_fade_in_item.dart';
import '../../screens/team_profile_screen.dart';
import 'champion_empty_state.dart';
import 'champion_podium_components.dart';

/// Monthly Competitive Ranking Tab (3/1/0 football points per governorate).
/// Strictly separated from Annual Team XP and Tournament placements.
class TeamsRankingTab extends StatefulWidget {
  final dynamic teamsStream; // Kept optional for backward widget test compatibility
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

  bool _isLoading = true;
  String? _error;
  String _monthKey = '';
  List<MonthlyRankingEntry> _entries = const [];
  Set<String> _myTeamIds = const {};

  @override
  void initState() {
    super.initState();
    _loadRanking();
  }

  @override
  void didUpdateWidget(covariant TeamsRankingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLocation != widget.selectedLocation ||
        oldWidget.selectedSport != widget.selectedSport) {
      _loadRanking();
    }
  }

  Future<void> _loadRanking() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.currentUser?.uid;
      final res = await GamificationRepository.instance.getMonthlyCompetitiveRanking(
        governorate: widget.selectedLocation,
      );

      final Set<String> myIds = {};
      if (uid != null && uid.isNotEmpty) {
        final myTeams = await (widget.teamRepository ?? TeamRepository()).getTeamsForUser(uid);
        myIds.addAll(myTeams.map((t) => t.id));
      }

      if (!mounted) return;
      final filtered = widget.selectedSport == 'All'
          ? res.teams
          : res.teams
              .where((t) => t.sportType.toLowerCase() == widget.selectedSport.toLowerCase())
              .toList();

      setState(() {
        _monthKey = res.monthKey;
        _entries = filtered;
        _myTeamIds = myIds;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showMostActiveModal(BuildContext context, bool isArabic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VSPColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        maxChildSize: 0.9,
        minChildSize: 0.45,
        expand: false,
        builder: (_, ctrl) => FutureBuilder<List<MostActiveTeamEntry>>(
          future: GamificationRepository.instance.getMostActiveTeamsRanking(
            governorate: widget.selectedLocation,
          ),
          builder: (ctx, snap) {
            final rows = snap.data ?? const [];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isArabic ? 'الفرق الأكثر نشاطاً (التصنيف السنوي)' : 'Most Active Teams (Annual)',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic
                        ? 'يعتمد على العدد الفعلي للتحديات المعتمدة خلال الموسم (مستقل عن ترتيب الشهر وعن الـ XP).'
                        : 'Ranked by verified completed challenges this season (independent of monthly rank and XP).',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (snap.connectionState == ConnectionState.waiting)
                    const Expanded(child: Center(child: CircularProgressIndicator(color: VSPColors.accent)))
                  else if (rows.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          isArabic ? 'لا توجد تحديات مكتملة في هذا الموسم حتى الآن.' : 'No completed challenges recorded yet.',
                          style: const TextStyle(color: VSPColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: ctrl,
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = rows[i];
                          return ListTile(
                            tileColor: VSPColors.surfaceAlt,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('#${r.activityRank}',
                                    style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900)),
                                const SizedBox(width: 8),
                                VspShieldBadge(tier: r.currentShield, size: 32, isArabic: isArabic),
                              ],
                            ),
                            title: Text(r.teamName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: Text('${r.governorate} • ${r.seasonYear}',
                                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  isArabic ? '${r.approvedChallenges} تحدٍ' : '${r.approvedChallenges} ch',
                                  style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                                Text(
                                  '${r.seasonXp.toStringAsFixed(0)} XP',
                                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
    }
    if (_error != null) {
      return VSPErrorState(
        customMessage: _error,
        onRetry: () {
          _loadRanking();
          widget.onRetry();
        },
      );
    }

    final headerBanner = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(color: VSPColors.divider),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.cup_copy, color: VSPColors.medalGold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic
                            ? 'الموسم التنافسي (${_monthKey.isNotEmpty ? _monthKey : 'شهرين'}) • جوائز الترتيب'
                            : '2-Month Season (${_monthKey.isNotEmpty ? _monthKey : 'Current'}) • Rank Rewards',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? '1-5: جوائز كاش 1,500 ج.م • 6-10: ساعة مجانية • الفوز 3 / التعادل 1'
                            : 'Top 1-5: 1,500 EGP Cash • 6-10: Free 1h • Win 3 / Draw 1',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showMostActiveModal(context, isArabic),
                  child: Text(
                    isArabic ? 'الأكثر نشاطاً' : 'Most Active',
                    style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildZonePill(
                  icon: Iconsax.money_recive_copy,
                  label: isArabic ? '1-5: كاش (500–180 ج.م)' : '1-5: 500–180 EGP',
                  color: VSPColors.medalGold,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildZonePill(
                  icon: Iconsax.ticket_discount_copy,
                  label: isArabic ? '6-10: ساعة مجانية' : '6-10: Free 1h',
                  color: VSPColors.medalSilver,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildZonePill(
                  icon: Iconsax.ranking_1_copy,
                  label: isArabic ? '11+: منافسة' : '11+: Compete',
                  color: VSPColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (_entries.isEmpty) {
      return Column(
        children: [
          headerBanner,
          const Expanded(child: TeamsEmptyState()),
        ],
      );
    }

    final top3 = _entries.take(3).toList();
    final rest = _entries.skip(3).toList();
    final myEntryIndex = _entries.indexWhere((e) => _myTeamIds.contains(e.teamId));
    final myEntry = myEntryIndex != -1 ? _entries[myEntryIndex] : null;

    Widget content;
    if (_entries.length < 3) {
      content = ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(context).padding.bottom + (myEntry != null ? 90 : 24)),
        physics: const BouncingScrollPhysics(),
        itemCount: _entries.length,
        itemBuilder: (ctx, i) => VSPFadeInItem(
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildRankListItem(context, _entries[i], isMyTeam: _myTeamIds.contains(_entries[i].teamId), isArabic: isArabic),
          ),
        ),
      );
    } else {
      content = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 4).copyWith(
          bottom: myEntry != null ? 96.0 : 40.0,
        ),
        child: Column(
          children: [
            SizedBox(
              height: 290,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: VSPFadeInItem(
                      index: 1,
                      child: ChampionPodiumItem(
                        rank: top3[1].rank,
                        name: top3[1].teamName,
                        logo: top3[1].logoUrl,
                        points: top3[1].rankingPoints,
                        badgeIcon: Iconsax.medal_star_copy,
                        borderColor: VSPColors.medalSilver,
                        bgColor: VSPColors.surface,
                        isMyTeam: _myTeamIds.contains(top3[1].teamId),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: VSPFadeInItem(
                      index: 0,
                      child: ChampionPodiumItem(
                        rank: top3[0].rank,
                        name: top3[0].teamName,
                        logo: top3[0].logoUrl,
                        points: top3[0].rankingPoints,
                        badgeIcon: Iconsax.crown_copy,
                        borderColor: VSPColors.medalGold,
                        bgColor: VSPColors.surfaceAlt,
                        isCenter: true,
                        isMyTeam: _myTeamIds.contains(top3[0].teamId),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: VSPFadeInItem(
                      index: 2,
                      child: ChampionPodiumItem(
                        rank: top3[2].rank,
                        name: top3[2].teamName,
                        logo: top3[2].logoUrl,
                        points: top3[2].rankingPoints,
                        badgeIcon: Iconsax.award_copy,
                        borderColor: VSPColors.medalBronze,
                        bgColor: VSPColors.surface,
                        isMyTeam: _myTeamIds.contains(top3[2].teamId),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildZoneHeader(
              icon: Iconsax.money_recive_copy,
              title: isArabic ? 'منطقة الجوائز النقدية (المراكز 1–5)' : 'Cash Rewards Zone (Ranks 1–5)',
              color: VSPColors.medalGold,
            ),
            const SizedBox(height: 8),
            ...List.generate(rest.length, (index) {
              final entry = rest[index];
              final prevRank = index == 0 ? 3 : rest[index - 1].rank;
              final showFreeZoneHeader = prevRank <= 5 && entry.rank >= 6 && entry.rank <= 10;
              final showCompZoneHeader = prevRank <= 10 && entry.rank >= 11;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showFreeZoneHeader) ...[
                    const SizedBox(height: 8),
                    _buildZoneHeader(
                      icon: Iconsax.ticket_discount_copy,
                      title: isArabic ? 'منطقة الساعة المجانية (المراكز 6–10)' : 'Free Booking Zone (Ranks 6–10)',
                      color: VSPColors.medalSilver,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (showCompZoneHeader) ...[
                    const SizedBox(height: 8),
                    _buildZoneHeader(
                      icon: Iconsax.ranking_1_copy,
                      title: isArabic ? 'منطقة المنافسة (11 فأكثر)' : 'Competition Zone (Ranks 11+)',
                      color: VSPColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                  ],
                  VSPFadeInItem(
                    index: index + 3,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildRankListItem(
                        context,
                        entry,
                        isMyTeam: _myTeamIds.contains(entry.teamId),
                        isArabic: isArabic,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      );
    }

    return Column(
      children: [
        headerBanner,
        Expanded(
          child: myEntry != null
              ? Stack(
                  children: [
                    content,
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: VSPColors.surfaceAlt.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(VSPRadius.lg),
                          border: Border.all(color: VSPColors.divider, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            VspShieldBadge(tier: myEntry.currentShield, size: 34, isArabic: isArabic),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${myEntry.teamName} • ${isArabic ? 'المركز #${myEntry.rank}' : 'Rank #${myEntry.rank}'}',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    VspSeasonRewards.nextTargetSummary(myEntry, _entries, isArabic: isArabic),
                                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
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
                                isArabic ? '${myEntry.rankingPoints} نقطة ترتيب' : '${myEntry.rankingPoints} pts',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : content,
        ),
      ],
    );
  }

  Widget _buildZonePill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankListItem(
    BuildContext context,
    MonthlyRankingEntry entry, {
    required bool isMyTeam,
    required bool isArabic,
  }) {
    final initialLetter =
        entry.teamName.trim().isNotEmpty ? entry.teamName.trim().split(' ').last.substring(0, 1).toUpperCase() : 'T';
    final zone = VspSeasonRewards.zoneForRank(entry.rank);
    final rewardLabel = VspSeasonRewards.rewardBadgeLabel(entry.rank, isArabic: isArabic);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TeamProfileScreen(teamId: entry.teamId)),
      ),
      borderRadius: BorderRadius.circular(VSPRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMyTeam ? VSPColors.surfaceAlt : VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(
            color: isMyTeam ? VSPColors.medalGold : VSPColors.divider.withValues(alpha: 0.35),
            width: isMyTeam ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#${entry.rank}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: entry.rank <= 3 ? VSPColors.accent : VSPColors.textSecondary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VSPColors.surfaceAlt,
                border: Border.all(color: VSPColors.divider, width: 1),
              ),
              child: ClipOval(
                child: entry.logoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: entry.logoUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => ChampionInitialBadge(letter: initialLetter, accentColor: VSPColors.accent),
                      )
                    : ChampionInitialBadge(letter: initialLetter, accentColor: VSPColors.accent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.teamName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isMyTeam ? VSPColors.accent : VSPColors.textPrimary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.currentShield != TeamShieldTier.none) ...[
                        const SizedBox(width: 6),
                        VspShieldBadge(tier: entry.currentShield, size: 20, isArabic: isArabic),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic
                        ? '${entry.governorate} • لعب ${entry.matchesPlayed} • ف ${entry.wins} • ت ${entry.draws} • خ ${entry.losses}'
                        : '${entry.governorate} • P ${entry.matchesPlayed} • W ${entry.wins} • D ${entry.draws} • L ${entry.losses}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (zone != RankingRewardZone.competition) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                margin: const EdgeInsets.only(right: 6, left: 6),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      zone == RankingRewardZone.cashRewards
                          ? Iconsax.money_recive_copy
                          : Iconsax.ticket_discount_copy,
                      size: 12,
                      color: zone == RankingRewardZone.cashRewards
                          ? VSPColors.medalGold
                          : VSPColors.medalSilver,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rewardLabel,
                      style: TextStyle(
                        color: zone == RankingRewardZone.cashRewards
                            ? VSPColors.medalGold
                            : VSPColors.medalSilver,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider.withValues(alpha: 0.4)),
              ),
              child: Text(
                isArabic ? '${entry.rankingPoints} نقطة' : '${entry.rankingPoints} pts',
                style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
