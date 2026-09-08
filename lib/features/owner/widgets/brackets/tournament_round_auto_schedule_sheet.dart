import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import 'tournament_auto_schedule_modal_sheet.dart';
import 'tournament_round_schedule_calculator.dart';

/// Auto Schedule banner and action triggers for a tournament round.
class TournamentRoundAutoScheduleBanner extends StatelessWidget {
  final Championship championship;
  final int roundIndex;
  final List<TournamentMatch> matches;
  final String roundName;
  final VoidCallback onRefresh;

  const TournamentRoundAutoScheduleBanner({
    super.key,
    required this.championship,
    required this.roundIndex,
    required this.matches,
    required this.roundName,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final bool hasScheduledMatches = matches.any((m) => m.scheduledTime != null);
    final bool isRoundStartedOrFinished = TournamentRoundScheduleCalculator.isRoundLocked(matches);

    // Locked if matches in this round have already started or finished
    if (isRoundStartedOrFinished) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.lock_copy, color: VSPColors.textSecondary, size: 14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'جدول مباريات $roundName (مُغلق )' : '$roundName Schedule (Locked )',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic
                        ? 'تم بدء مباريات هذا الدور وتسجيل نتائجها (لا يمكن إعادة الجدولة التلقائية)'
                        : 'Matches in this round have started (Auto-scheduling locked)',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.magic_star_copy, color: VSPColors.accent, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic
                      ? (hasScheduledMatches ? 'تعديل جدول $roundName' : 'جدولة تلقائية لمباريات $roundName')
                      : (hasScheduledMatches ? 'Manage $roundName Schedule' : 'Auto-Schedule $roundName'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  isArabic
                      ? (hasScheduledMatches
                          ? 'تم جدولة مباريات هذا الدور. يمكنك التصفير أو إعادة الجدولة'
                          : 'توليد المواعيد والتواريخ تلقائياً لـ ${matches.length} مباراة')
                      : (hasScheduledMatches
                          ? 'Matches scheduled. You can reset or re-schedule.'
                          : 'Auto generate dates for ${matches.length} matches'),
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (hasScheduledMatches) ...[
            IconButton(
              tooltip: isArabic ? 'تصفير الجدول وإلغاء المواعيد ' : 'Reset Round Schedule',
              icon: const Icon(Iconsax.rotate_left_copy, color: VSPColors.error, size: 16),
              onPressed: () {
                showResetRoundScheduleConfirmationDialog(
                  context,
                  championshipId: championship.id,
                  roundIndex: roundIndex,
                  matches: matches,
                  roundName: roundName,
                  onScheduleReset: onRefresh,
                );
              },
            ),
            const SizedBox(width: 4),
          ],
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () {
              showAutoScheduleModalSheet(
                context,
                championship: championship,
                roundIndex: roundIndex,
                matches: matches,
                roundName: roundName,
                onScheduleSaved: onRefresh,
              );
            },
            child: Text(
              isArabic
                  ? (hasScheduledMatches ? 'إعادة الجدولة ' : 'جدولة ')
                  : (hasScheduledMatches ? 'Re-Schedule ' : 'Schedule '),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reset round match schedule confirmation dialog.
void showResetRoundScheduleConfirmationDialog(
  BuildContext context, {
  required String championshipId,
  required int roundIndex,
  required List<TournamentMatch> matches,
  required String roundName,
  required VoidCallback onScheduleReset,
}) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';

  showDialog(
    context: context,
    builder: (dialogCtx) {
      return AlertDialog(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Iconsax.rotate_left_copy, color: VSPColors.warning, size: 18),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'تصفير جدول $roundName' : 'Reset $roundName Schedule',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'هل أنت تأكد من إلغاء وتصفير مواعيد جميع مباريات ($roundName) وإعادتها إلى "غير مجدول"؟'
              : 'Are you sure you want to reset all match dates for ($roundName) to unscheduled?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await TournamentRepository().clearRoundMatchSchedules(
                championshipId: championshipId,
                roundIndex: roundIndex,
                matches: matches,
              );

              if (success && context.mounted) {
                onScheduleReset();
                VSPFeedback.showSuccess(
                  context,
                  isArabic
                      ? ' تم تصفير وإلغاء جدول مباريات $roundName بنجاح!'
                      : ' Reset schedule for $roundName successfully!',
                );
              }
            },
            child: Text(isArabic ? 'تأكيد التصفير ' : 'Confirm Reset'),
          ),
        ],
      );
    },
  );
}

/// Modal bottom sheet to configure auto-scheduling parameters.
void showAutoScheduleModalSheet(
  BuildContext context, {
  required Championship championship,
  required int roundIndex,
  required List<TournamentMatch> matches,
  required String roundName,
  required VoidCallback onScheduleSaved,
}) {
  TournamentAutoScheduleModalSheet.show(
    context,
    championship: championship,
    roundIndex: roundIndex,
    matches: matches,
    roundName: roundName,
    onScheduleSaved: onScheduleSaved,
  );
}
