import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../data/models.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';

class TournamentBracketsScreen extends StatelessWidget {
  final Championship championship;
  final bool isOwner;

  const TournamentBracketsScreen({super.key, required this.championship, required this.isOwner});

  // دالة لجلب كشف أسماء اللاعبين (أونلاين وأوفلاين) لكلا الفريقين عبر TournamentRepository
  Future<Map<String, List<String>>> _fetchRosters(String homeTeamId, String awayTeamId) async {
    return TournamentRepository().fetchRosters(championship.id, homeTeamId, awayTeamId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<List<TournamentMatch>>(
      stream: TournamentRepository().getTournamentMatches(championship.id),
      builder: (context, snapshot) {
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
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: Center(child: Text(l10n.noBracketsYet, style: const TextStyle(color: VSPColors.textSecondary))),
          );
        }

        // تجميع المباريات حسب رقم الدور
        final Map<int, List<TournamentMatch>> groupedMatches = {};
        for (var match in matches) {
          groupedMatches.putIfAbsent(match.roundIndex, () => []).add(match);
        }

        final sortedRounds = groupedMatches.keys.toList()..sort((a, b) => b.compareTo(a));

        return DefaultTabController(
          length: sortedRounds.length,
          child: Scaffold(
            backgroundColor: VSPColors.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? FontAwesomeIcons.chevronRight
                      : FontAwesomeIcons.chevronLeft,
                  color: VSPColors.textPrimary,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(l10n.tournamentBrackets, style: Theme.of(context).textTheme.displaySmall),
              bottom: TabBar(
                isScrollable: true,
                indicatorColor: VSPColors.accent,
                labelColor: VSPColors.accent,
                unselectedLabelColor: VSPColors.textSecondary,
                tabs: sortedRounds.map((roundIdx) {
                  return Tab(text: _getRoundLabel(context, roundIdx, sortedRounds.length));
                }).toList(),
              ),
            ),
            body: TabBarView(
              children: sortedRounds.map((roundIdx) {
                final roundMatches = groupedMatches[roundIdx]!;
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 110),
                  itemCount: roundMatches.length,
                  itemBuilder: (context, index) {
                    final match = roundMatches[index];
                    return _buildMatchCard(context, match);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _getRoundLabel(BuildContext context, int roundIndex, int totalRounds) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

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

  Widget _buildMatchCard(BuildContext context, TournamentMatch match) {
    final l10n = AppLocalizations.of(context)!;
    final hasSchedule = match.scheduledTime != null;
    final isTimePassed = hasSchedule && DateTime.now().isAfter(match.scheduledTime!);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hasSchedule 
                      ? DateFormat('MMM d, hh:mm a').format(match.scheduledTime!) 
                      : l10n.notScheduled,
                  style: TextStyle(color: hasSchedule ? VSPColors.accent : VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                if (isOwner)
                  GestureDetector(
                    onTap: () async {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (time != null) {
                        final dt = DateTime.now();
                        await TournamentRepository().updateMatchScheduledTime(
                          matchId: match.id,
                          scheduledTime: DateTime(dt.year, dt.month, dt.day, time.hour, time.minute),
                        );
                      }
                    },
                    child: const Icon(FontAwesomeIcons.calendarCheck, color: Colors.white, size: 16),
                  ),
              ],
            ),
          ),
          ListTile(
            title: Text('${match.homeTeamName ?? "TBD"} vs ${match.awayTeamName ?? "TBD"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              match.winnerId != null 
                  ? 'Winner: ${match.winnerId == match.homeTeamId ? match.homeTeamName : match.awayTeamName} (${match.homeScore} - ${match.awayScore})' 
                  : 'Pending', 
              style: TextStyle(color: match.winnerId != null ? VSPColors.accent : Colors.white54)
            ),
            // أيقونة التعديل تفتح الآن نافذة تسجيل النتيجة وعرض الكشوفات التفاعلية
            trailing: isOwner && match.winnerId == null && match.homeTeamId != null && match.awayTeamId != null 
              ? IconButton(
                  icon: const Icon(FontAwesomeIcons.penToSquare, color: VSPColors.accent, size: 18),
                  onPressed: () {
                    if (!hasSchedule) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.matchScheduledFor("يجب التحديد أولاً")), backgroundColor: VSPColors.error));
                      return;
                    }
                    if (!isTimePassed) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن إدخال النتيجة إلا بعد انتهاء وقت المباراة المجدول! ⚠️', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: VSPColors.error));
                      return;
                    }
                    // فتح شاشة تسجيل النتيجة التفاعلية
                    _showScoreInputDialog(context, match);
                  },
                ) 
              : null,
          ),
        ],
      ),
    );
  }

  // 🕒 واجهة تسجيل النتيجة المتقدمة للبطولة
  void _showScoreInputDialog(BuildContext context, TournamentMatch match) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        int homeScore = 0;
        int awayScore = 0;
        String? selectedWinnerId; // لمعالجة التعادل في الكأس
        bool isSubmitting = false;

        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.85,
          decoration: const BoxDecoration(
            color: VSPColors.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(VSPRadius.xl),
              topRight: Radius.circular(VSPRadius.xl),
            ),
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              final isCupAndTied = championship.type == 'Cup' && homeScore == awayScore;
              final bool isValidToSubmit = !isCupAndTied || selectedWinnerId != null;

              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isArabic ? 'تسجيل نتيجة المباراة' : 'Submit Match Score', style: Theme.of(context).textTheme.displaySmall),
                        IconButton(
                          icon: Icon(FontAwesomeIcons.xmark, color: VSPColors.textSecondary, size: 18),
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
                          // 🏁 واجهة تسجيل الأهداف التفاعلية لكلا الفريقين
                          Row(
                            children: [
                              // الفريق الأول (المستضيف)
                              Expanded(
                                child: _buildScoreCounterColumn(
                                  teamName: match.homeTeamName ?? 'Team A',
                                  score: homeScore,
                                  onIncrement: () => setModalState(() {
                                    homeScore++;
                                    selectedWinnerId = null;
                                  }),
                                  onDecrement: () => setModalState(() {
                                    if (homeScore > 0) homeScore--;
                                    selectedWinnerId = null;
                                  }),
                                ),
                              ),
                              const Text('VS', style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 24)),
                              // الفريق الثاني (الضيف)
                              Expanded(
                                child: _buildScoreCounterColumn(
                                  teamName: match.awayTeamName ?? 'Team B',
                                  score: awayScore,
                                  onIncrement: () => setModalState(() {
                                    awayScore++;
                                    selectedWinnerId = null;
                                  }),
                                  onDecrement: () => setModalState(() {
                                    if (awayScore > 0) awayScore--;
                                    selectedWinnerId = null;
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ⚔️ سيناريو التعادل في الكأس (ركلات الترجيح)
                          if (isCupAndTied) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
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
                                        ? '⚠️ لا يسمح بالتعادل في مباريات خروج المغلوب' 
                                        : '⚠️ Draws not allowed in knockout matches',
                                    style: const TextStyle(color: VSPColors.warning, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isArabic 
                                        ? 'يرجى تحديد الفريق الفائز بركلات الترجيح لتصعيده:' 
                                        : 'Please select the team that won on penalties to advance:',
                                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
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

                          // 👥 جلب وعرض كشف أسماء اللاعبين (Roster Viewer)
                          Text(
                            isArabic ? '📋 كشف أسماء اللاعبين المشاركين بالبطولة:' : '📋 Championship Team Rosters:',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<Map<String, List<String>>>(
                            future: _fetchRosters(match.homeTeamId!, match.awayTeamId!),
                            builder: (context, rosterSnapshot) {
                              if (rosterSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: VSPColors.accent)));
                              }

                              final homeRoster = rosterSnapshot.data?['home'] ?? [];
                              final awayRoster = rosterSnapshot.data?['away'] ?? [];

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // كشف الفريق الأول
                                  Expanded(child: _buildRosterListColumn(match.homeTeamName ?? 'Home', homeRoster)),
                                  const SizedBox(width: 12),
                                  // كشف الفريق الثاني
                                  Expanded(child: _buildRosterListColumn(match.awayTeamName ?? 'Away', awayRoster)),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // أزرار التأكيد والإرسال
                  Container(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
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
                            text: isArabic ? 'تأكيد النتيجة وتصعيد الفائز' : 'Submit & Advance',
                            isLoading: isSubmitting,
                            onPressed: !isValidToSubmit ? null : () async {
                              setModalState(() => isSubmitting = true);
                              try {
                                // حساب الفائز الفعلي بناءً على النتيجة أو ركلات الترجيح
                                final finalWinnerId = (homeScore == awayScore)
                                    ? selectedWinnerId
                                    : (homeScore > awayScore ? match.homeTeamId : match.awayTeamId);

                                final finalWinnerName = finalWinnerId == match.homeTeamId
                                    ? match.homeTeamName
                                    : match.awayTeamName;

                                // إرسال النتيجة لجدول ومحرك البطولة
                                await TournamentRepository().updateTournamentMatchScore(
                                  matchId: match.id,
                                  homeScore: homeScore,
                                  awayScore: awayScore,
                                  winnerId: finalWinnerId,
                                  winnerName: finalWinnerName,
                                );

                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isArabic ? '🏆 تم حفظ النتيجة وتصعيد الفائز تلقائياً!' : '🏆 Score saved and winner advanced!'),
                                      backgroundColor: VSPColors.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: VSPColors.error),
                                  );
                                }
                              } finally {
                                setModalState(() => isSubmitting = false);
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
          ),
        );
      },
    );
  }

  // مكوّن عداد الأهداف التفاعلي
  Widget _buildScoreCounterColumn({
    required String teamName,
    required int score,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Column(
      children: [
        Text(teamName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onDecrement,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: VSPColors.surfaceAlt, shape: BoxShape.circle),
                child: const Icon(FontAwesomeIcons.minus, color: Colors.white, size: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('$score', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            ),
            GestureDetector(
              onTap: onIncrement,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: VSPColors.accent, shape: BoxShape.circle),
                child: const Icon(FontAwesomeIcons.plus, color: Colors.black, size: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // زر تحديد الفائز بركلات الترجيح
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

  // عمود كشف اللاعبين المشاركين
  Widget _buildRosterListColumn(String teamName, List<String> roster) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(teamName, style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(8)),
          child: roster.isEmpty
              ? const Text('لا يوجد لاعبون مسجلون', style: TextStyle(color: VSPColors.textSecondary, fontSize: 11))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: roster.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final name = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${idx + 1}. $name', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
