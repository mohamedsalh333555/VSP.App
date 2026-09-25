import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../player/widgets/championship_details/championship_standings_table.dart';
import '../widgets/brackets/tournament_champion_banner.dart';
import '../widgets/brackets/tournament_match_card.dart';
import '../widgets/brackets/tournament_round_auto_schedule_sheet.dart';

class TournamentBracketsScreen extends StatefulWidget {
  final Championship championship;
  final bool isOwner;

  const TournamentBracketsScreen({super.key, required this.championship, required this.isOwner});

  @override
  State<TournamentBracketsScreen> createState() => _TournamentBracketsScreenState();
}

class _TournamentBracketsScreenState extends State<TournamentBracketsScreen> {
  int _refreshKey = 0;
  final TransformationController _transformController = TransformationController();

  void _refreshMatches() {
    if (mounted) {
      setState(() {
        _refreshKey++;
      });
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Widget _buildAdvanceGroupsBanner(BuildContext context, bool isArabic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isArabic ? 'اكتملت مواجهات دور المجموعات!' : 'Group Stage Completed!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'انتهت جميع مباريات المجموعات، يمكنك الآن اعتماد صعود الفرق المتأهلة وبدء شجرة الأدوار الإقصائية.'
                : 'All group matches are finished. Advance top qualifiers to the knockout rounds now.',
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12.5, height: 1.3),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: isArabic ? 'اعتماد المتأهلين وبدء الأدوار الإقصائية' : 'Advance Qualifiers to Knockout',
              height: 44,
              onPressed: () async {
                try {
                  await TournamentRepository().advanceGroupsToKnockout(widget.championship.id);
                  _refreshMatches();
                  if (context.mounted) {
                    VSPFeedback.showSuccess(
                      context,
                      isArabic
                          ? 'تم تصعيد الفرق المتأهلة وبدء شجرة الأدوار الإقصائية بنجاح!'
                          : 'Qualifiers advanced to knockout rounds successfully!',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    VSPFeedback.showError(
                      context,
                      isArabic ? 'حدث خطأ أثناء تصعيد المتأهلين: $e' : 'Error advancing qualifiers: $e',
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isLeague = widget.championship.type == 'League';
    final isStandingsEligible = isLeague || widget.championship.type == 'GroupsAndKnockout';

    return StreamBuilder<List<TournamentMatch>>(
      key: ValueKey(_refreshKey),
      stream: TournamentRepository().getTournamentMatches(widget.championship.id),
      builder: (context, snapshot) {
        if (snapshot.hasError && (!snapshot.hasData || snapshot.data!.isEmpty)) {
          return Scaffold(
            backgroundColor: VSPColors.background,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const VSPBackButton()),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.refresh_copy, color: VSPColors.warning, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'تعذر التحديث اللحظي، اسحب للأسفل للتحديث',
                    style: TextStyle(color: VSPColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _refreshKey++),
                    icon: const Icon(Iconsax.refresh_copy, size: 18),
                    label: const Text('إعادة المحاولة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.accent,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: VSPColors.background,
            body: Center(child: CircularProgressIndicator(color: VSPColors.accent)),
          );
        }

        final matches = snapshot.data!;
        if (matches.isEmpty) {
          return Scaffold(
            backgroundColor: VSPColors.background,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const VSPBackButton()),
            body: Center(child: Text(l10n.noBracketsYet, style: const TextStyle(color: VSPColors.textSecondary))),
          );
        }

        // Check if group stage is completed and needs advance to knockout
        final isGroups = widget.championship.type == 'GroupsAndKnockout';
        final hasKnockoutMatches = matches.any((m) => m.roundIndex < 99 && m.stage != 'group_stage');
        final groupMatches = matches.where((m) => m.stage == 'group_stage' || m.roundIndex == 99).toList();
        final canAdvanceGroups = isGroups &&
            widget.isOwner &&
            !hasKnockoutMatches &&
            groupMatches.isNotEmpty &&
            groupMatches.every((m) => m.isCompleted || m.homeScore != null);

        // Group matches by round index
        final Map<int, List<TournamentMatch>> groupedMatches = {};
        for (var match in matches) {
          groupedMatches.putIfAbsent(match.roundIndex, () => []).add(match);
        }

        final sortedRounds = groupedMatches.keys.toList()
          ..sort((a, b) => isLeague ? a.compareTo(b) : b.compareTo(a));

        final totalTabs = sortedRounds.length + (isStandingsEligible ? 1 : 0);

        return DefaultTabController(
          length: totalTabs,
          child: Scaffold(
            backgroundColor: VSPColors.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: const VSPBackButton(),
              title: Text(
                isLeague
                    ? (isArabic ? 'جدول ومباريات الدوري' : 'League Matches & Standings')
                    : l10n.tournamentBrackets,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              bottom: TabBar(
                isScrollable: true,
                indicatorColor: VSPColors.accent,
                labelColor: VSPColors.accent,
                unselectedLabelColor: VSPColors.textSecondary,
                tabs: [
                  if (isStandingsEligible)
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.award_copy, size: 16),
                          const SizedBox(width: 6),
                          Text(isArabic ? 'جدول الترتيب' : 'Standings'),
                        ],
                      ),
                    ),
                  ...sortedRounds.map((roundIdx) {
                    return Tab(text: _getRoundLabel(context, roundIdx, sortedRounds.length));
                  }),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                if (isStandingsEligible)
                  RefreshIndicator(
                    onRefresh: () async => _refreshMatches(),
                    color: VSPColors.accent,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 16, 16, VSPScrollPadding.bottom(context, hasFloatingNavBar: true)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (canAdvanceGroups) _buildAdvanceGroupsBanner(context, isArabic),
                          ChampionshipStandingsSection(championship: widget.championship),
                        ],
                      ),
                    ),
                  ),
                ...sortedRounds.map((roundIdx) {
                  final roundMatches = groupedMatches[roundIdx]!;
                  final showChampion = !isLeague && roundIdx == 0 && roundMatches.isNotEmpty && roundMatches.first.winnerId != null;
                  final showOwnerBanner = widget.isOwner;
                  final showAdvanceGroups = roundIdx == 99 && canAdvanceGroups;
                  final headerOffset = (showChampion ? 1 : 0) + (showOwnerBanner ? 1 : 0) + (showAdvanceGroups ? 1 : 0);
                  final totalItems = headerOffset + roundMatches.length;
                  final roundName = _getRoundLabel(context, roundIdx, sortedRounds.length);

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, VSPScrollPadding.bottom(context, hasFloatingNavBar: true)),
                    itemCount: totalItems,
                    itemBuilder: (context, index) {
                      var currentIndex = index;
                      if (showChampion) {
                        if (currentIndex == 0) {
                          final winnerName = roundMatches.first.winnerId == roundMatches.first.homeTeamId
                              ? (roundMatches.first.homeTeamName ?? 'Winner')
                              : (roundMatches.first.awayTeamName ?? 'Winner');
                          return TournamentChampionBanner(championName: winnerName);
                        }
                        currentIndex--;
                      }

                      if (showAdvanceGroups) {
                        if (currentIndex == 0) {
                          return _buildAdvanceGroupsBanner(context, isArabic);
                        }
                        currentIndex--;
                      }

                      if (showOwnerBanner) {
                        if (currentIndex == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TournamentRoundAutoScheduleBanner(
                              championship: widget.championship,
                              roundIndex: roundIdx,
                              matches: roundMatches,
                              roundName: roundName,
                              onRefresh: _refreshMatches,
                            ),
                          );
                        }
                        currentIndex--;
                      }

                      return TournamentMatchCard(
                        match: roundMatches[currentIndex],
                        championship: widget.championship,
                        isOwner: widget.isOwner,
                        onRefresh: _refreshMatches,
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getRoundLabel(BuildContext context, int roundIndex, int totalRounds) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (roundIndex == 99) {
      return isArabic ? 'دور المجموعات' : 'Group Stage';
    }

    if (widget.championship.type == 'League') {
      return isArabic ? 'الجولة ${roundIndex + 1}' : 'Round ${roundIndex + 1}';
    }

    switch (roundIndex) {
      case 0:
        return l10n.finalRound;
      case 1:
        return l10n.semiFinalRound;
      case 2:
        return l10n.quarterFinalRound;
      case 3:
        return isArabic ? 'دور الـ 16' : 'Round of 16';
      case 4:
        return isArabic ? 'دور الـ 32' : 'Round of 32';
      default:
        if (roundIndex == totalRounds - 1) {
          return isArabic ? 'الجولة التمهيدية' : 'Preliminary Round';
        }
        return 'Round ${roundIndex + 1}';
    }
  }
}
