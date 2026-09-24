import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
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
                      child: ChampionshipStandingsSection(championship: widget.championship),
                    ),
                  ),
                ...sortedRounds.map((roundIdx) {
                  final roundMatches = groupedMatches[roundIdx]!;
                  final showChampion = !isLeague && roundIdx == 0 && roundMatches.isNotEmpty && roundMatches.first.winnerId != null;
                  final showOwnerBanner = widget.isOwner;
                  final headerOffset = (showChampion ? 1 : 0) + (showOwnerBanner ? 1 : 0);
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
