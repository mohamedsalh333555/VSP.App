import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';

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

  int homeScore = match.homeScore ?? goalDetails.where((g) => g.teamId == match.homeTeamId).length;
  int awayScore = match.awayScore ?? goalDetails.where((g) => g.teamId == match.awayTeamId).length;
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

                if (isCupAndTied && homePenalties != awayPenalties) {
                  if (homePenalties > awayPenalties) {
                    selectedWinnerId = match.homeTeamId;
                  } else if (awayPenalties > homePenalties) {
                    selectedWinnerId = match.awayTeamId;
                  }
                }

                final bool isValidToSubmit = !isCupAndTied || selectedWinnerId != null;

                final homeGoals = goalDetails.where((g) => g.teamId == match.homeTeamId).toList();
                final awayGoals = goalDetails.where((g) => g.teamId == match.awayTeamId).toList();

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
                                  child: _buildScoreCounterColumn(
                                    teamName: match.homeTeamName ?? 'Team A',
                                    score: homeScore,
                                    onIncrement: () {
                                      _openAddGoalModal(
                                        modalContext,
                                        teamId: match.homeTeamId ?? 'home',
                                        teamName: match.homeTeamName ?? 'Team A',
                                        roster: homeRoster,
                                        onGoalAdded: (goal) {
                                          setModalState(() {
                                            goalDetails.add(goal);
                                            homeScore++;
                                            selectedWinnerId = null;
                                          });
                                        },
                                      );
                                    },
                                    onDecrement: () => setModalState(() {
                                      if (homeScore > 0) {
                                        homeScore--;
                                        if (homeGoals.isNotEmpty) {
                                          goalDetails.remove(homeGoals.last);
                                        }
                                        selectedWinnerId = null;
                                      }
                                    }),
                                  ),
                                ),
                                const Text('VS',
                                    style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 24)),
                                Expanded(
                                  child: _buildScoreCounterColumn(
                                    teamName: match.awayTeamName ?? 'Team B',
                                    score: awayScore,
                                    onIncrement: () {
                                      _openAddGoalModal(
                                        modalContext,
                                        teamId: match.awayTeamId ?? 'away',
                                        teamName: match.awayTeamName ?? 'Team B',
                                        roster: awayRoster,
                                        onGoalAdded: (goal) {
                                          setModalState(() {
                                            goalDetails.add(goal);
                                            awayScore++;
                                            selectedWinnerId = null;
                                          });
                                        },
                                      );
                                    },
                                    onDecrement: () => setModalState(() {
                                      if (awayScore > 0) {
                                        awayScore--;
                                        if (awayGoals.isNotEmpty) {
                                          goalDetails.remove(awayGoals.last);
                                        }
                                        selectedWinnerId = null;
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
                                  child: _buildGoalScorersList(
                                    teamName: match.homeTeamName ?? 'Team A',
                                    goals: homeGoals,
                                    onRemoveGoal: (goal) {
                                      setModalState(() {
                                        goalDetails.remove(goal);
                                        if (homeScore > 0) homeScore--;
                                      });
                                    },
                                    isArabic: isArabic,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildGoalScorersList(
                                    teamName: match.awayTeamName ?? 'Team B',
                                    goals: awayGoals,
                                    onRemoveGoal: (goal) {
                                      setModalState(() {
                                        goalDetails.remove(goal);
                                        if (awayScore > 0) awayScore--;
                                      });
                                    },
                                    isArabic: isArabic,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 3. Penalty Shootout (Knockout Draw Scenario)
                            if (isCupAndTied) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: VSPColors.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(VSPRadius.md),
                                  border: Border.all(color: VSPColors.warning.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isArabic
                                          ? 'ركلات الترجيح / Penalties Shootout'
                                          : 'Penalty Shootout (Knockout Draw)',
                                      style: const TextStyle(
                                          color: VSPColors.warning, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isArabic
                                          ? 'أدخل أهداف ركلات الترجيح وحدد الفريق المتأهل:'
                                          : 'Enter penalty goals & select advancing team:',
                                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildScoreCounterColumn(
                                            teamName: '${match.homeTeamName ?? "Home"} (ركلات)',
                                            score: homePenalties,
                                            onIncrement: () => setModalState(() {
                                              homePenalties++;
                                              if (homePenalties > awayPenalties) selectedWinnerId = match.homeTeamId;
                                            }),
                                            onDecrement: () => setModalState(() {
                                              if (homePenalties > 0) homePenalties--;
                                              if (homePenalties > awayPenalties) {
                                                selectedWinnerId = match.homeTeamId;
                                              } else if (awayPenalties > homePenalties) {
                                                selectedWinnerId = match.awayTeamId;
                                              }
                                            }),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildScoreCounterColumn(
                                            teamName: '${match.awayTeamName ?? "Away"} (ركلات)',
                                            score: awayPenalties,
                                            onIncrement: () => setModalState(() {
                                              awayPenalties++;
                                              if (awayPenalties > homePenalties) selectedWinnerId = match.awayTeamId;
                                            }),
                                            onDecrement: () => setModalState(() {
                                              if (awayPenalties > 0) awayPenalties--;
                                              if (homePenalties > awayPenalties) {
                                                selectedWinnerId = match.homeTeamId;
                                              } else if (awayPenalties > homePenalties) {
                                                selectedWinnerId = match.awayTeamId;
                                              }
                                            }),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildPenaltyWinnerButton(
                                            label: match.homeTeamName ?? 'Home',
                                            isSelected: selectedWinnerId == match.homeTeamId,
                                            onTap: () => setModalState(() => selectedWinnerId = match.homeTeamId),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildPenaltyWinnerButton(
                                            label: match.awayTeamName ?? 'Away',
                                            isSelected: selectedWinnerId == match.awayTeamId,
                                            onTap: () => setModalState(() => selectedWinnerId = match.awayTeamId),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            const Divider(color: VSPColors.divider),
                            const SizedBox(height: 12),

                            // 4. Team Rosters Viewer
                            Text(
                              isArabic ? ' كشف أسماء اللاعبين المشاركين بالبطولة:' : ' Championship Team Rosters:',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            if (rosterSnapshot.connectionState == ConnectionState.waiting)
                              const Center(
                                  child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(color: VSPColors.accent)))
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: _buildRosterListColumn(match.homeTeamName ?? 'Home', homeRoster)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: _buildRosterListColumn(match.awayTeamName ?? 'Away', awayRoster)),
                                ],
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
                                            isArabic
                                                ? 'حدث خطأ أثناء تسجيل النتيجة'
                                                : 'Error submitting score',
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

Widget _buildScoreCounterColumn({
  required String teamName,
  required int score,
  required VoidCallback onIncrement,
  required VoidCallback onDecrement,
}) {
  return Column(
    children: [
      Text(
        teamName,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: VSPColors.surfaceAlt, shape: BoxShape.circle),
              child: const Icon(Iconsax.minus_cirlce_copy, color: Colors.white, size: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$score',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: VSPColors.accent, shape: BoxShape.circle),
              child: const Icon(Iconsax.add_circle_copy, color: Colors.black, size: 14),
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildGoalScorersList({
  required String teamName,
  required List<GoalItem> goals,
  required Function(GoalItem goal) onRemoveGoal,
  required bool isArabic,
}) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: VSPColors.surface,
      borderRadius: BorderRadius.circular(VSPRadius.md),
      border: Border.all(color: VSPColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.element_4_copy, color: VSPColors.accent, size: 12),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isArabic ? 'هدافو $teamName' : '$teamName Scorers',
                style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (goals.isEmpty)
          Text(isArabic ? 'لم يتم تسجيل أهداف بعد' : 'No goals recorded',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: goals.map((g) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '⚽ ${g.playerName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => onRemoveGoal(g),
                      child: const Icon(Iconsax.close_circle_copy, color: Colors.white54, size: 10),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    ),
  );
}

void _openAddGoalModal(
  BuildContext context, {
  required String teamId,
  required String teamName,
  required List<String> roster,
  required Function(GoalItem goal) onGoalAdded,
}) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final TextEditingController customNameController = TextEditingController();
  String? selectedFromRoster;

  showDialog(
    context: context,
    builder: (dlgCtx) {
      return StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: VSPColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
            title: Row(
              children: [
                const Icon(Iconsax.element_4_copy, color: VSPColors.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic ? 'تسجيل هدف لـ $teamName ' : 'Record Goal for $teamName ',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (roster.isNotEmpty) ...[
                    Text(
                      isArabic ? 'اختر اسم الهداف من كشف اللاعبين:' : 'Select scorer from roster:',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: VSPColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.divider),
                      ),
                      child: DropdownButton<String>(
                        value: selectedFromRoster,
                        isExpanded: true,
                        hint: Text(isArabic ? 'اختر لاعباً...' : 'Select a player...',
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        dropdownColor: VSPColors.surface,
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: roster.map((name) {
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDlgState(() {
                            selectedFromRoster = val;
                            if (val != null) customNameController.text = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(isArabic ? 'أو' : 'OR',
                          style: const TextStyle(
                              color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    isArabic ? 'ادخل اسم الهداف يدوياً (للقوائم اليدوية):' : 'Enter scorer name manually:',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: customNameController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: isArabic ? 'مثال: أحمد حسام / لاعب 1' : 'e.g. Ahmed / Player 1',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: VSPColors.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        borderSide: const BorderSide(color: VSPColors.divider),
                      ),
                    ),
                    onChanged: (val) {
                      if (selectedFromRoster != null && val != selectedFromRoster) {
                        setDlgState(() => selectedFromRoster = null);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  final finalName = customNameController.text.trim().isNotEmpty
                      ? customNameController.text.trim()
                      : (selectedFromRoster ?? (isArabic ? 'لاعب مجهول' : 'Unknown Player'));

                  onGoalAdded(GoalItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    teamId: teamId,
                    playerName: finalName,
                    isOwnGoal: false,
                  ));
                  Navigator.pop(dlgCtx);
                },
                child:
                    Text(isArabic ? 'حفظ الهدف ' : 'Save Goal ', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  ).then((_) {
    customNameController.dispose();
  });
}

Widget _buildPenaltyWinnerButton({
  required String label,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? VSPColors.accent : VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: isSelected ? VSPColors.accent : VSPColors.divider, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

Widget _buildRosterListColumn(String teamName, List<String> roster) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(teamName,
          style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(8)),
        child: roster.isEmpty
            ? const Text('لا يوجد لاعبون مسجلون',
                style: TextStyle(color: VSPColors.textSecondary, fontSize: 11))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: roster.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final name = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${idx + 1}. $name',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  );
                }).toList(),
              ),
      ),
    ],
  );
}
