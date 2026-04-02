import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../data/models.dart';

class TournamentBracketsScreen extends StatelessWidget {
  final Championship championship;
  final bool isOwner;

  const TournamentBracketsScreen({
    super.key,
    required this.championship,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: VSPColors.textPrimary),
        title: Text(
          AppLocalizations.of(context)!.tournamentBrackets,
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: StreamBuilder<List<TournamentMatch>>(
        stream: TournamentRepository().getTournamentMatches(championship.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }

          final matches = snapshot.data ?? [];

          if (matches.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.noBracketsYet,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
              ),
            );
          }

          // Group by Round
          final rounds = <int, List<TournamentMatch>>{};
          for (var match in matches) {
            rounds.putIfAbsent(match.roundIndex, () => []).add(match);
          }
          
          // Sort rounds (High index = Early rounds, Low index = Final)
          final sortedRoundIndices = rounds.keys.toList()..sort((a, b) => b.compareTo(a));

          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
                scrollDirection: Axis.horizontal,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: sortedRoundIndices.map((roundIndex) {
                      return _buildRoundColumn(context, roundIndex, rounds[roundIndex]!);
                    }).toList(),
                  ),
                ),
              );
            }
          );
        },
      ),
    );
  }

  Widget _buildRoundColumn(BuildContext context, int roundIndex, List<TournamentMatch> matches) {
    matches.sort((a, b) => a.matchIndex.compareTo(b.matchIndex));
    
    String roundName = AppLocalizations.of(context)!.roundOf(matches.length * 2);
    if (roundIndex == 0) {
      roundName = AppLocalizations.of(context)!.finalRound;
    } else if (roundIndex == 1) {
      roundName = AppLocalizations.of(context)!.semiFinalRound;
    } else if (roundIndex == 2) {
      roundName = AppLocalizations.of(context)!.quarterFinalRound;
    }

    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(horizontal: VSPSpacing.xs),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: VSPSpacing.md),
            child: Text(
              roundName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: VSPColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 20), // Spacing between matches
            itemBuilder: (context, index) {
              return _MatchNode(
                match: matches[index],
                isOwner: isOwner,
                onTap: isOwner ? () => _showScoreDialog(context, matches[index]) : null,
                onScheduleTap: isOwner ? () => _showScheduleDialog(context, matches[index]) : null,
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Schedule Date/Time Dialog ──
  void _showScheduleDialog(BuildContext context, TournamentMatch match) async {
    // 1. Pick Date
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: match.scheduledTime ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: VSPColors.accent,
              onPrimary: Colors.black,
              surface: VSPColors.surface,
              onSurface: VSPColors.textPrimary,
            ),
            dialogBackgroundColor: VSPColors.background,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !context.mounted) return;

    // 2. Pick Time
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: match.scheduledTime != null
          ? TimeOfDay.fromDateTime(match.scheduledTime!)
          : const TimeOfDay(hour: 20, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: VSPColors.accent,
              onPrimary: Colors.black,
              surface: VSPColors.surface,
              onSurface: VSPColors.textPrimary,
            ),
            dialogBackgroundColor: VSPColors.background,
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null || !context.mounted) return;

    // 3. Combine Date + Time
    final scheduledDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // 4. Save to Firestore
    try {
      await TournamentRepository().updateMatchScheduledTime(
        matchId: match.id,
        scheduledTime: scheduledDateTime,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.matchScheduledFor(DateFormat('MMM d, hh:mm a').format(scheduledDateTime))),
            backgroundColor: VSPColors.accent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: VSPColors.error),
        );
      }
    }
  }

  void _showScoreDialog(BuildContext context, TournamentMatch match) {
    // Prevent editing if not fully populated
    if (match.homeTeamId == null || match.awayTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.waitingPreviousWinners)),
      );
      return;
    }

    final homeController = TextEditingController(text: match.homeScore?.toString());
    final awayController = TextEditingController(text: match.awayScore?.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(AppLocalizations.of(context)!.updateScore, style: Theme.of(context).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildScoreInput(context, match.homeTeamName ?? AppLocalizations.of(context)!.home, homeController),
            const SizedBox(height: VSPSpacing.md),
            _buildScoreInput(context, match.awayTeamName ?? AppLocalizations.of(context)!.na, awayController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: VSPColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final h = int.tryParse(homeController.text) ?? 0;
              final a = int.tryParse(awayController.text) ?? 0;
              
              if (h == a) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.drawNotAllowed)),
                );
                return;
              }

              String winnerId = h > a ? match.homeTeamId! : match.awayTeamId!;
              String winnerName = h > a ? match.homeTeamName! : match.awayTeamName!;

              Navigator.pop(context);
              
              await TournamentRepository().updateTournamentMatchScore(
                matchId: match.id,
                homeScore: h,
                awayScore: a,
                winnerId: winnerId,
                winnerName: winnerName,
              );
            },
            child: Text(AppLocalizations.of(context)!.saveLabel, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: VSPColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreInput(BuildContext context, String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
        SizedBox(
          width: 60,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: VSPColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
              contentPadding: const EdgeInsets.all(8),
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchNode extends StatelessWidget {
  final TournamentMatch match;
  final bool isOwner;
  final VoidCallback? onTap;
  final VoidCallback? onScheduleTap;

  const _MatchNode({required this.match, required this.isOwner, this.onTap, this.onScheduleTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: match.winnerId != null ? VSPColors.accent : VSPColors.divider,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // ── Scheduled Time Display ──
            _buildScheduleBar(context),
            _buildTeamRow(context, match.homeTeamName, match.homeScore, 
                isWinner: match.winnerId != null && match.winnerId == match.homeTeamId),
            const Divider(height: 1, color: VSPColors.divider),
            _buildTeamRow(context, match.awayTeamName, match.awayScore, 
                isWinner: match.winnerId != null && match.winnerId == match.awayTeamId),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleBar(BuildContext context) {
    final hasSchedule = match.scheduledTime != null;
    final formattedTime = hasSchedule
        ? DateFormat('MMM d, hh:mm a').format(match.scheduledTime!)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hasSchedule
            ? VSPColors.accent.withValues(alpha: 0.08)
            : VSPColors.surfaceAlt.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(VSPRadius.md)),
      ),
      child: Row(
        children: [
          Icon(
            hasSchedule ? Icons.event_available : Icons.schedule,
            size: 13,
            color: hasSchedule ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              formattedTime ?? AppLocalizations.of(context)!.notScheduled,
              style: TextStyle(
                color: hasSchedule ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: hasSchedule ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isOwner)
            GestureDetector(
              onTap: onScheduleTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                ),
                child: Text(
                  hasSchedule ? AppLocalizations.of(context)!.editLabel : AppLocalizations.of(context)!.apply,
                  style: const TextStyle(
                    color: VSPColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamRow(BuildContext context, String? name, int? score, {bool isWinner = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isWinner ? VSPColors.accent.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(VSPRadius.md), // Slight rounding for the inner row
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name ?? AppLocalizations.of(context)!.na,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: name == null
                        ? VSPColors.textSecondary.withValues(alpha: 0.5)
                        : (isWinner ? VSPColors.accent : VSPColors.textPrimary),
                    fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (score != null)
            Text(
              score.toString(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isWinner ? VSPColors.accent : VSPColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
        ],
      ),
    );
  }
}
