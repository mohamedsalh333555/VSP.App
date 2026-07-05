import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../data/models.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class TournamentBracketsScreen extends StatelessWidget {
  final Championship championship;
  final bool isOwner;

  const TournamentBracketsScreen({super.key, required this.championship, required this.isOwner});

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

        // Group matches by roundIndex
        final Map<int, List<TournamentMatch>> groupedMatches = {};
        for (var match in matches) {
          groupedMatches.putIfAbsent(match.roundIndex, () => []).add(match);
        }

        // Sort roundIndex in descending order (highest round Index i.e. Round of 16/Quarters first, final roundIndex 0 last)
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
                icon: const Icon(LucideIcons.chevronLeft, color: VSPColors.textPrimary),
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
                  padding: const EdgeInsets.all(16),
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
        return l10n.finalRound; // النهائي
      case 1:
        return l10n.semiFinalRound; // نصف النهائي
      case 2:
        return l10n.quarterFinalRound; // ربع النهائي
      case 3:
        return isArabic ? 'دور الـ 16' : 'Round of 16';
      case 4:
        return isArabic ? 'دور الـ 32' : 'Round of 32';
      default:
        // إذا كانت الجولة التمهيدية الأولى غير المنتظمة في الحسابات التراكمية
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
                    child: const Icon(LucideIcons.calendarClock, color: Colors.white, size: 18),
                  ),
              ],
            ),
          ),
          ListTile(
            title: Text('${match.homeTeamName ?? "TBD"} vs ${match.awayTeamName ?? "TBD"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(match.winnerId != null ? 'Winner: ${match.winnerId == match.homeTeamId ? match.homeTeamName : match.awayTeamName}' : 'Pending', style: TextStyle(color: match.winnerId != null ? VSPColors.accent : Colors.white54)),
            // 🛡️ قفل الحماية: نتحقق من أن الفريقين محددان بالفعل (ليسا null) قبل إتاحة أيقونة التعديل
            trailing: isOwner && match.winnerId == null && match.homeTeamId != null && match.awayTeamId != null 
              ? IconButton(
                  icon: const Icon(LucideIcons.pencilLine, color: VSPColors.accent),
                  onPressed: () {
                    if (!hasSchedule) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.matchScheduledFor("يجب التحديد أولاً")), backgroundColor: VSPColors.error));
                      return;
                    }
                    if (!isTimePassed) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن إدخال النتيجة إلا بعد انتهاء وقت المباراة المجدول! ⚠️', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: VSPColors.error));
                      return;
                    }
                    TournamentRepository().updateTournamentMatchScore(
                      matchId: match.id, 
                      homeScore: 1, 
                      awayScore: 0, 
                      winnerId: match.homeTeamId!, 
                      winnerName: match.homeTeamName!
                    );
                  },
                ) 
              : null,
          ),
        ],
      ),
    );
  }
}