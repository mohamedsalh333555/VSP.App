import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/app_date_formatter.dart';
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final hasSchedule = match.scheduledTime != null;
    final tbdText = isAr ? 'لم يحدد' : 'TBD';
    final winnerName = match.winnerId == match.homeTeamId ? (match.homeTeamName ?? tbdText) : (match.awayTeamName ?? tbdText);

    final String scheduleText = hasSchedule
        ? '${AppDateFormatter.formatDayMonth(match.scheduledTime!, isAr ? "ar" : "en")}، ${AppDateFormatter.formatTime(match.scheduledTime!, isAr ? "ar" : "en")}'
        : l10n.notScheduled;

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
                  scheduleText,
                  style: TextStyle(
                    color: hasSchedule ? VSPColors.accent : VSPColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isOwner)
                  GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final initialDate = (match.scheduledTime != null && match.scheduledTime!.isAfter(now))
                          ? match.scheduledTime!
                          : now;
                      final date = await showDatePicker(
                        context: context,
                        initialDate: initialDate,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (date == null || !context.mounted) return;

                      final initialTime = match.scheduledTime != null
                          ? TimeOfDay.fromDateTime(match.scheduledTime!)
                          : TimeOfDay.now();
                      final time = await showTimePicker(
                        context: context,
                        initialTime: initialTime,
                      );
                      if (time != null && context.mounted) {
                        await TournamentRepository().updateMatchScheduledTime(
                          matchId: match.id,
                          scheduledTime: DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ),
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
              '${match.homeTeamName ?? tbdText} vs ${match.awayTeamName ?? tbdText}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              match.winnerId != null
                  ? (isAr
                      ? 'الفائز: $winnerName (${match.homeScore} - ${match.awayScore})'
                      : 'Winner: $winnerName (${match.homeScore} - ${match.awayScore})')
                  : (isAr ? 'قيد الانتظار' : 'Pending'),
              style: TextStyle(color: match.winnerId != null ? VSPColors.accent : Colors.white54),
            ),
            trailing: isOwner && match.homeTeamId != null && match.awayTeamId != null
                ? IconButton(
                    tooltip: match.winnerId != null
                        ? (isAr ? 'تعديل النتيجة' : 'Edit Score')
                        : (isAr ? 'تسجيل النتيجة' : 'Enter Score'),
                    icon: Icon(
                      match.winnerId != null ? Iconsax.edit_2_copy : Iconsax.edit_copy,
                      color: VSPColors.accent,
                      size: 18,
                    ),
                    onPressed: () {
                      if (!hasSchedule) {
                        VSPFeedback.showError(
                          context,
                          isAr ? 'يجب تحديد موعد المباراة أولاً!' : 'Match must be scheduled first!',
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
