import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import 'tournament_score_modal.dart';

/// Card representing an individual tournament match slot with scheduling and score entry.
class TournamentMatchCard extends StatelessWidget {
  final TournamentMatch match;
  final Championship championship;
  final bool isOwner;
  final VoidCallback onRefresh;

  const TournamentMatchCard({
    super.key,
    required this.match,
    required this.championship,
    required this.isOwner,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
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
                  hasSchedule ? DateFormat('MMM d, hh:mm a').format(match.scheduledTime!) : l10n.notScheduled,
                  style: TextStyle(
                    color: hasSchedule ? VSPColors.accent : VSPColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
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
                        onRefresh();
                      }
                    },
                    child: const Icon(Iconsax.calendar_1_copy, color: Colors.white, size: 16),
                  ),
              ],
            ),
          ),
          ListTile(
            title: Text(
              '${match.homeTeamName ?? "TBD"} vs ${match.awayTeamName ?? "TBD"}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              match.winnerId != null
                  ? 'Winner: ${match.winnerId == match.homeTeamId ? match.homeTeamName : match.awayTeamName} (${match.homeScore} - ${match.awayScore})'
                  : 'Pending',
              style: TextStyle(color: match.winnerId != null ? VSPColors.accent : Colors.white54),
            ),
            trailing: isOwner && match.winnerId == null && match.homeTeamId != null && match.awayTeamId != null
                ? IconButton(
                    icon: Icon(
                      Iconsax.edit_copy,
                      color: (!hasSchedule || !isTimePassed)
                          ? VSPColors.textSecondary.withValues(alpha: 0.5)
                          : VSPColors.accent,
                      size: 18,
                    ),
                    onPressed: () {
                      final isAr = Localizations.localeOf(context).languageCode == 'ar';
                      if (!hasSchedule) {
                        VSPFeedback.showError(
                            context, isAr ? 'يجب تحديد موعد المباراة أولاً!' : 'Match must be scheduled first!');
                        return;
                      }
                      if (!isTimePassed) {
                        VSPFeedback.showError(
                          context,
                          isAr
                              ? 'لا يمكن إدخال النتيجة إلا بعد انتهاء وقت المباراة المجدول! '
                              : 'Cannot enter score before scheduled match time!',
                        );
                        return;
                      }
                      showTournamentScoreModal(
                        context,
                        match: match,
                        championship: championship,
                        onScoreSaved: onRefresh,
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
