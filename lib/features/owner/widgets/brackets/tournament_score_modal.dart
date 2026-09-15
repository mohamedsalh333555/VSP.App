import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';
import 'score_modal/goal_scorers_section.dart';
import 'score_modal/penalty_shootout_section.dart';
import 'score_modal/roster_list_viewer.dart';
import 'score_modal/score_counter_column.dart';

/// Interactive modal sheet to record match score, penalty shootout, and individual goal scorers.
void showTournamentScoreModal(
  BuildContext context, {
  required TournamentMatch match,
  required Championship championship,
  required VoidCallback onScoreSaved,
}) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final List<GoalItem> goalDetails = List.from(match.goalDetails);

  // Cache the Future ONCE so FutureBuilder doesn't re-trigger loading on every setModalState!
  final Future<Map<String, List<String>>> rostersFuture =
      TournamentRepository().fetchRosters(championship.id, match.homeTeamId ?? '', match.awayTeamId ?? '');

  int computeHomeScore() {
    if (goalDetails.isNotEmpty) {
      final normal = goalDetails.where((g) => g.teamId == match.homeTeamId && !g.isOwnGoal).length;
      final opponentOwn = goalDetails.where((g) => g.teamId == match.awayTeamId && g.isOwnGoal).length;
      return normal + opponentOwn;
    }
    return match.homeScore ?? 0;
  }

  int computeAwayScore() {
    if (goalDetails.isNotEmpty) {
      final normal = goalDetails.where((g) => g.teamId == match.awayTeamId && !g.isOwnGoal).length;
      final opponentOwn = goalDetails.where((g) => g.teamId == match.homeTeamId && g.isOwnGoal).length;
      return normal + opponentOwn;
    }
    return match.awayScore ?? 0;
  }

  int homeScore = computeHomeScore();
  int awayScore = computeAwayScore();
  int homePenalties = match.homePenalties ?? 0;
  int awayPenalties = match.awayPenalties ?? 0;
  String? selectedWinnerId = match.winnerId;
  bool isSubmitting = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: VSPColors.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(VSPRadius.xl),
            topRight: Radius.circular(VSPRadius.xl),
          ),
        ),
        child: FutureBuilder<Map<String, List<String>>>(
          future: rostersFuture,
          builder: (context, rosterSnapshot) {
            final homeRoster = rosterSnapshot.data?['home'] ?? [];
            final awayRoster = rosterSnapshot.data?['away'] ?? [];

            return StatefulBuilder(
              builder: (BuildContext modalContext, StateSetter setModalState) {
                final isKnockoutOrCup =
                    championship.type == 'Cup' || match.stage == 'knockout' || match.stage == 'preliminary';
                final isCupAndTied = isKnockoutOrCup && homeScore == awayScore;

                if (isCupAndTied) {
                  if (homePenalties != awayPenalties) {
                    if (homePenalties > awayPenalties) {
                      selectedWinnerId = match.homeTeamId;
                    } else if (awayPenalties > homePenalties) {
                      selectedWinnerId = match.awayTeamId;
                    }
                  }
                } else if (isKnockoutOrCup) {
                  selectedWinnerId = homeScore > awayScore ? match.homeTeamId : match.awayTeamId;
                }

                final bool isValidToSubmit = !isCupAndTied || selectedWinnerId != null;

                final homeGoals = goalDetails
                    .where((g) => (g.teamId == match.homeTeamId && !g.isOwnGoal) || (g.teamId == match.awayTeamId && g.isOwnGoal))
                    .toList();
                final awayGoals = goalDetails
                    .where((g) => (g.teamId == match.awayTeamId && !g.isOwnGoal) || (g.teamId == match.homeTeamId && g.isOwnGoal))
                    .toList();

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isArabic ? 'تسجيل نتيجة وهدافي المباراة ' : 'Submit Score & Goal Scorers ',
                            style: Theme.of(modalContext).textTheme.displaySmall,
                          ),
                          IconButton(
                            icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 18),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: VSPColors.divider),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Interactive score counters
                            Row(
                              children: [
                                Expanded(
                                  child: ScoreCounterColumn(
                                    teamName: match.homeTeamName ?? 'Team A',
                                    score: homeScore,
                                    onIncrement: () {
                                      openAddGoalModal(
                                        modalContext,
                                        teamId: match.homeTeamId ?? 'home',
                                        teamName: match.homeTeamName ?? 'Team A',
                                        roster: homeRoster,
                                        onGoalAdded: (goal) {
                                          setModalState(() {
                                            goalDetails.add(goal);
                                            homeScore = computeHomeScore();
                                            awayScore = computeAwayScore();
                                            if (homeScore != awayScore) {
                                              selectedWinnerId = homeScore > awayScore ? match.homeTeamId : match.awayTeamId;
                                            }
                                          });
                                        },
                                      );
                                    },
                                    onDecrement: () => setModalState(() {
                                      if (homeGoals.isNotEmpty) {
                                        goalDetails.remove(homeGoals.last);
                                        homeScore = computeHomeScore();
                                        awayScore = computeAwayScore();
                                      } else if (homeScore > 0) {
                                        homeScore--;
                                      }
                                      if (homeScore != awayScore) {
                                        selectedWinnerId = homeScore > awayScore ? match.homeTeamId : match.awayTeamId;
                                      }
                                    }),
                                  ),
                                ),
                                const Text(
                                  'VS',
                                  style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 24),
                                ),
                                Expanded(
                                  child: ScoreCounterColumn(
                                    teamName: match.awayTeamName ?? 'Team B',
                                    score: awayScore,
                                    onIncrement: () {
                                      openAddGoalModal(
                                        modalContext,
                                        teamId: match.awayTeamId ?? 'away',
                                        teamName: match.awayTeamName ?? 'Team B',
                                        roster: awayRoster,
                                        onGoalAdded: (goal) {
                                          setModalState(() {
                                            goalDetails.add(goal);
                                            homeScore = computeHomeScore();
                                            awayScore = computeAwayScore();
                                            if (homeScore != awayScore) {
                                              selectedWinnerId = homeScore > awayScore ? match.homeTeamId : match.awayTeamId;
                                            }
                                          });
                                        },
                                      );
                                    },
                                    onDecrement: () => setModalState(() {
                                      if (awayGoals.isNotEmpty) {
                                        goalDetails.remove(awayGoals.last);
                                        homeScore = computeHomeScore();
                                        awayScore = computeAwayScore();
                                      } else if (awayScore > 0) {
                                        awayScore--;
                                      }
                                      if (homeScore != awayScore) {
                                        selectedWinnerId = homeScore > awayScore ? match.homeTeamId : match.awayTeamId;
                                      }
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 2. Goal scorers lists
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: GoalScorersList(
                                    teamName: match.homeTeamName ?? 'Team A',
                                    goals: homeGoals,
                                    onRemoveGoal: (goal) {
                                      setModalState(() {
                                        goalDetails.remove(goal);
                                        homeScore = computeHomeScore();
                                        awayScore = computeAwayScore();
                                        if (homeScore != awayScore) {
                                          selectedWinnerId = homeScore > awayScore ? match.homeTeamId : match.awayTeamId;
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GoalScorersList(
                                    teamName: match.awayTeamName ?? 'Team B',
                                    goals: awayGoals,
                                    onRemoveGoal: (goal) {
                                      setModalState(() {
                                        goalDetails.remove(goal);
                                        homeScore = computeHomeScore();
                                        awayScore = computeAwayScore();
                                        if (homeScore != awayScore) {
                                          selectedWinnerId = homeScore > awayScore ? match.homeTeamId : match.awayTeamId;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 3. Penalty Shootout (Knockout Draw Scenario)
                            if (isCupAndTied) ...[
                              PenaltyShootoutSection(
                                match: match,
                                homePenalties: homePenalties,
                                awayPenalties: awayPenalties,
                                selectedWinnerId: selectedWinnerId,
                                onIncrementHome: () => setModalState(() {
                                  homePenalties++;
                                  if (homePenalties > awayPenalties) selectedWinnerId = match.homeTeamId;
                                }),
                                onDecrementHome: () => setModalState(() {
                                  if (homePenalties > 0) homePenalties--;
                                  if (homePenalties > awayPenalties) {
                                    selectedWinnerId = match.homeTeamId;
                                  } else if (awayPenalties > homePenalties) {
                                    selectedWinnerId = match.awayTeamId;
                                  }
                                }),
                                onIncrementAway: () => setModalState(() {
                                  awayPenalties++;
                                  if (awayPenalties > homePenalties) selectedWinnerId = match.awayTeamId;
                                }),
                                onDecrementAway: () => setModalState(() {
                                  if (awayPenalties > 0) awayPenalties--;
                                  if (homePenalties > awayPenalties) {
                                    selectedWinnerId = match.homeTeamId;
                                  } else if (awayPenalties > homePenalties) {
                                    selectedWinnerId = match.awayTeamId;
                                  }
                                }),
                                onSelectWinner: (winnerId) => setModalState(() => selectedWinnerId = winnerId),
                              ),
                              const SizedBox(height: 24),
                            ],

                            const Divider(color: VSPColors.divider),
                            const SizedBox(height: 12),

                            // 4. Team Rosters Viewer
                            RosterListViewer(
                              homeTeamName: match.homeTeamName ?? 'Home',
                              homeRoster: homeRoster,
                              awayTeamName: match.awayTeamName ?? 'Away',
                              awayRoster: awayRoster,
                              isLoading: rosterSnapshot.connectionState == ConnectionState.waiting,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Confirmation Buttons
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        MediaQuery.of(sheetContext).padding.bottom +
                            MediaQuery.of(sheetContext).viewInsets.bottom +
                            16,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              text: isArabic ? 'إلغاء' : 'Cancel',
                              color: VSPColors.surfaceAlt,
                              textColor: VSPColors.textPrimary,
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              text: isArabic ? 'تأكيد النتيجة والهدافين ' : 'Submit & Advance',
                              isLoading: isSubmitting,
                              onPressed: !isValidToSubmit
                                  ? null
                                  : () async {
                                      setModalState(() => isSubmitting = true);
                                      try {
                                        final finalWinnerId = (homeScore == awayScore)
                                            ? selectedWinnerId
                                            : (homeScore > awayScore ? match.homeTeamId : match.awayTeamId);

                                        final finalWinnerName = finalWinnerId == match.homeTeamId
                                            ? match.homeTeamName
                                            : match.awayTeamName;

                                        await TournamentRepository().updateTournamentMatchScore(
                                          matchId: match.id,
                                          homeScore: homeScore,
                                          awayScore: awayScore,
                                          homePenalties: isCupAndTied ? homePenalties : null,
                                          awayPenalties: isCupAndTied ? awayPenalties : null,
                                          winnerId: finalWinnerId,
                                          winnerName: finalWinnerName,
                                          goalDetails: goalDetails,
                                        );

                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext);
                                        }
                                        if (context.mounted) {
                                          onScoreSaved();
                                          VSPFeedback.showSuccess(
                                            context,
                                            isArabic
                                                ? 'تم تسجيل نتيجة المباراة وهدافيها وتصعيد $finalWinnerName بنجاح.'
                                                : 'Match score, goal scorers saved & $finalWinnerName advanced successfully.',
                                          );
                                        }
                                      } catch (e) {
                                        setModalState(() => isSubmitting = false);
                                        if (sheetContext.mounted) {
                                          VSPFeedback.showError(
                                            sheetContext,
                                            isArabic ? 'حدث خطأ أثناء تسجيل النتيجة' : 'Error submitting score',
                                          );
                                        }
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      );
    },
  );
}
