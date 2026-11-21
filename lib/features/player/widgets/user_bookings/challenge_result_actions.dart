import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/repositories/booking/challenge_non_played_report_repository.dart';
import '../../../../core/services/vsp_time_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/vsp_animated_button.dart';
import '../../screens/team_profile_screen.dart';
import '../match_result_modal.dart';
import 'challenge_non_played_report_status.dart';
import 'challenge_non_played_appeal_dialog.dart';

/// Challenge result flow: both captains submit independently.
/// The match is finalized only when both submissions match.
class ChallengeResultActions extends StatelessWidget {
  final Booking booking;
  final String? myTeamId;
  final ChallengeNonPlayedReportStatus? reportStatus;
  /// Opt in ONLY after the scoped report-status RPC has been deployed.
  /// Required but unavailable status blocks stale win badges and actions.
  final bool reportLookupRequired;
  /// Only enable through the server-gated captain card.
  final bool allowAppeal;
  final VoidCallback? onReportChanged;
  /// Test-only destination injection; runtime uses the established team profile.
  final Widget Function(String teamId)? teamProfileBuilder;
  final Future<ChallengeReportCommandReceipt> Function(String reason)?
      appealSubmitOverride;

  const ChallengeResultActions({
    super.key,
    required this.booking,
    this.myTeamId,
    this.reportStatus,
    this.reportLookupRequired = false,
    this.allowAppeal = false,
    this.onReportChanged,
    this.teamProfileBuilder,
    this.appealSubmitOverride,
  });

  /// A result is not final for player-facing progress until both captains
  /// agreed, the booking actually completed, and an outcome is present.
  /// This does not claim that Elo/points were processed or that no later
  /// official correction was issued by the server.
  static bool hasCompletedChallengeResult(Booking booking) =>
      booking.bookingType == BookingType.challenge &&
      booking.status == BookingStatus.completed &&
      booking.matchResultStatus == MatchResultStatus.confirmed &&
      booking.finalOutcome != null &&
      !booking.endTime.isAfter(VSPTimeService.now);

  static Widget buildChallengeStatusBadge(
    BuildContext context, {
    required Booking booking,
    required String? myTeamId,
    ChallengeNonPlayedReportStatus? reportStatus,
    bool reportLookupRequired = false,
  }) {
    final currentTeamId = myTeamId;
    if (currentTeamId == null ||
        (currentTeamId != booking.playerTeamId &&
            currentTeamId != booking.opponentTeamId)) {
      return const SizedBox.shrink();
    }
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    // Unknown is not equivalent to no report. Do not display an outdated win.
    if (reportLookupRequired && reportStatus == null) {
      return buildStatusBadge(
        isArabic ? 'جارٍ التحقق من بلاغ المباراة' : 'Checking match report status',
        VSPColors.warning,
      );
    }
    if (reportStatus?.isExcluded == true) {
      return buildStatusBadge(
        reportStatus!.underReview
            ? (isArabic ? 'بلاغ قيد المراجعة' : 'Report under review')
            : (isArabic ? 'المباراة مستبعدة' : 'Match excluded'),
        VSPColors.warning,
      );
    }
    final l10n = AppLocalizations.of(context)!;
    final isHome = currentTeamId == booking.playerTeamId;
    final isAway = currentTeamId == booking.opponentTeamId;

    if (booking.matchResultStatus == MatchResultStatus.confirmed) {
      if (!hasCompletedChallengeResult(booking)) {
        return buildStatusBadge(
          isArabic ? 'النتيجة النهائية غير متاحة' : 'Final result unavailable',
          VSPColors.warning,
        );
      }
      final outcome = booking.finalOutcome;
      // A confirmed flag without a final outcome is inconsistent data.
      // Never label it as a loss just because the outcome is missing.
      if (outcome == null) {
        return buildStatusBadge(
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'النتيجة غير متاحة'
              : 'Result unavailable',
          VSPColors.warning,
        );
      }
      if (outcome == MatchOutcome.draw) {
        return buildStatusBadge(l10n.draw, VSPColors.info);
      }
      final won = (outcome == MatchOutcome.homeWin && isHome) ||
          (outcome == MatchOutcome.awayWin && isAway);
      return buildStatusBadge(
        won ? l10n.win : l10n.loss,
        won ? VSPColors.warning : VSPColors.error,
      );
    }

    if (booking.matchResultStatus == MatchResultStatus.waitingOpponent) {
      final submittedTeamId = booking.resultSubmittedByTeamId;
      // The opponent's outcome may be withheld until we submit our own.
      // Submission metadata alone is enough to show the waiting status.
      final hasSubmissionDetails =
          submittedTeamId != null && submittedTeamId.isNotEmpty;
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      final submittedByMe = submittedTeamId == currentTeamId;
      final canSubmitNow = !booking.endTime.isAfter(VSPTimeService.now);
      return buildStatusBadge(
        !hasSubmissionDetails
            ? (isArabic ? 'جارٍ تحديث حالة النتيجة' : 'Syncing result status')
            : submittedByMe
                ? (isArabic
                    ? 'في انتظار نتيجة الفريق الآخر'
                    : 'Waiting for the other team result')
                : canSubmitNow
                    ? (isArabic
                        ? 'الفريق الآخر سجّل نتيجته، سجّل نتيجتك'
                        : 'Opponent submitted; record your result')
                    : (isArabic
                        ? 'الفريق الآخر سجّل نتيجته، انتظر انتهاء المباراة'
                        : 'Opponent submitted; wait until the match ends'),
        VSPColors.warning,
      );
    }

    if (booking.matchResultStatus == MatchResultStatus.disputed) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      return buildStatusBadge(
        isArabic ? 'النتيجتان مختلفتان' : 'Results do not match',
        VSPColors.warning,
      );
    }

    // Only bookings without a submitted result can prompt submission.
    // Unknown or disputed statuses must not be presented as "Submit result".
    if (booking.matchResultStatus == MatchResultStatus.noResult &&
        !booking.endTime.isAfter(VSPTimeService.now)) {
      return buildStatusBadge(l10n.submitResult, VSPColors.warning);
    }

    return const SizedBox.shrink();
  }

  static Widget buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VSPSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _openResultModal(BuildContext context, String teamId) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return VSPAnimatedButton(
      text: isArabic ? 'تسجيل نتيجتي' : 'Record my result',
      color: VSPColors.accent,
      textColor: VSPColors.black,
      onPressed: () {
        showDialog(
          context: context,
          builder: (dialogContext) => MatchResultModal(
            booking: booking,
            submittingTeamId: teamId,
            onConfirm: (outcome, rating, review) async {
              final provider =
                  Provider.of<BookingProvider>(context, listen: false);
              final success = await provider.submitMatchResult(
                bookingId: booking.id,
                teamId: teamId,
                outcome: outcome,
                rating: rating,
                review: review,
              );

              if (!context.mounted) return false;

              if (success) {
                VSPFeedback.showSuccess(
                  context,
                  isArabic
                      ? 'تم تسجيل نتيجتك. لن تُعتمد المباراة إلا عند تطابق النتيجتين.'
                      : 'Your result was recorded. The match is finalized only when both results match.',
                );
              }
              // MatchResultModal owns failure feedback. Showing another
              // snackbar here would duplicate the same error for the user.
              return success;
            },
          ),
        );
      },
    );
  }

  Future<void> _submitAppeal(BuildContext context, bool isArabic) async {
    final reason = await ChallengeNonPlayedAppealDialog.show(
      context, isArabic: isArabic,
    );
    if (!context.mounted || reason == null) return;
    final repo = ChallengeNonPlayedReportRepository();
    try {
      final receipt = await (appealSubmitOverride?.call(reason) ??
          repo.captainAppeal(bookingId: booking.id, reason: reason));
      if (!context.mounted) return;
      var confirmed = receipt.accepted && receipt.state == 'under_review';
      if (!confirmed &&
          appealSubmitOverride == null &&
          reportStatus?.myAppealSubmitted != true) {
        // A timeout is ambiguous. Readback can confirm the FIRST appeal,
        // but NOT an edited reason: a previous appeal's presence would be
        // mistaken for confirmation of a newly submitted edit.
        final fresh = await repo.fetchMyReportStatus(booking.id);
        confirmed = fresh?['state'] == 'excluded' &&
            fresh?['my_appeal_submitted'] == true;
      }
      if (!context.mounted) return;
      if (confirmed) {
        VSPFeedback.showSuccess(context, isArabic
            ? 'تم إرسال الاعتراض، والمباراة مستبعدة حتى انتهاء المراجعة.'
            : 'Appeal submitted. The match stays excluded until review.');
        onReportChanged?.call();
      } else {
        VSPFeedback.showError(context, isArabic
            ? 'تعذر تأكيد الاعتراض. راجع حالته قبل إعادة المحاولة.'
            : 'Could not verify appeal. Check its status before retrying.');
      }
    } catch (_) {
      // Never log a private appeal reason or result vote.
      if (context.mounted) {
        VSPFeedback.showError(context, isArabic
            ? 'تعذر الاتصال. تحقق من حالة الاعتراض وأعد المحاولة.'
            : 'Connection error. Check appeal status before retrying.');
      }
    }
  }

  void _openTeamProfile(BuildContext context, String teamId) {
    if (teamId.isEmpty ||
        (teamId != booking.playerTeamId &&
            teamId != booking.opponentTeamId)) return;
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => teamProfileBuilder?.call(teamId) ??
          TeamProfileScreen(teamId: teamId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final currentTeamId = myTeamId;
    // Only the two teams participating in this booking may be offered
    // result submission. The server remains the final authorization gate.
    if (currentTeamId == null ||
        (currentTeamId != booking.playerTeamId &&
            currentTeamId != booking.opponentTeamId)) {
      return const SizedBox.shrink();
    }

    // Until the scoped report RPC succeeds, an old confirmed booking may
    // already have been excluded. Never present rankings or a result button.
    if (reportLookupRequired && reportStatus == null) {
      return buildStatusBadge(
        isArabic
            ? 'تعذر التحقق من بلاغ المباراة. أعد المحاولة.'
            : 'Match report status unavailable. Please retry.',
        VSPColors.warning,
      );
    }

    // A server-confirmed exclusion overrides an old 'confirmed' result.
    // A captain must never submit another outcome while the report is open.
    if (reportStatus?.isExcluded == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChallengeNonPlayedReportBanner(status: reportStatus!),
          if (allowAppeal) ...[
            const SizedBox(height: VSPSpacing.xs),
            if (reportStatus!.myAppealSubmitted)
              Text(
                isArabic ? 'تم تسجيل اعتراض فريقك.'
                    : 'Your team appeal is recorded.',
                style: const TextStyle(
                  color: VSPColors.textSecondary, fontSize: 12,
                ),
              ),
            TextButton.icon(
              onPressed: () => _submitAppeal(context, isArabic),
              icon: const Icon(Icons.rate_review_outlined, size: 16),
              label: Text(reportStatus!.myAppealSubmitted
                  ? (isArabic ? 'تحديث الاعتراض' : 'Update appeal')
                  : (isArabic ? 'اعتراض قائد الفريق' : 'Captain appeal')),
            ),
          ],
        ],
      );
    }
    if (reportStatus?.isRestored == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChallengeNonPlayedReportBanner(status: reportStatus!),
          const SizedBox(height: VSPSpacing.sm),
          ChallengeResultActions(booking: booking, myTeamId: currentTeamId),
        ],
      );
    }

    if (booking.matchResultStatus == MatchResultStatus.noResult) {
      // The repository rejects early submissions. Do not offer an action
      // that cannot succeed until the match has actually ended.
      if (booking.endTime.isAfter(VSPTimeService.now)) {
        return const SizedBox.shrink();
      }
      return _openResultModal(context, currentTeamId);
    }

    if (booking.matchResultStatus == MatchResultStatus.waitingOpponent) {
      final submittedByMe =
          booking.resultSubmittedByTeamId == currentTeamId;
      // A redacted opponent choice must not hide their submitted state.
      final hasSubmissionDetails =
          booking.resultSubmittedByTeamId?.isNotEmpty == true;

      // Do not reveal the opponent's choice before independent submission.
      // Server-side field isolation is tracked separately in RESULT-03.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(VSPSpacing.md),
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  submittedByMe
                      ? Iconsax.clock_copy
                      : Iconsax.info_circle_copy,
                  color: VSPColors.warning,
                  size: 18,
                ),
                const SizedBox(width: VSPSpacing.sm),
                Expanded(
                  child: Text(
                    !hasSubmissionDetails
                        ? (isArabic
                            ? 'جارٍ تحديث حالة النتيجة'
                            : 'Syncing result status')
                        : submittedByMe
                            ? (isArabic
                            ? 'تم تسجيل نتيجتك. في انتظار نتيجة الفريق المنافس.'
                            : 'Your result is recorded. Waiting for the opponent.')
                        : (isArabic
                            ? 'الفريق المنافس سجّل نتيجته. سجّل نتيجتك بشكل مستقل.'
                            : 'Opponent submitted. Record your result independently.'),
                    style: const TextStyle(
                      color: VSPColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (hasSubmissionDetails &&
                !submittedByMe &&
                !booking.endTime.isAfter(VSPTimeService.now)) ...[
              const SizedBox(height: VSPSpacing.xs),
              Text(
                isArabic
                    ? 'سجل نتيجتك الصحيحة. إذا اختلفت النتيجتان، لن تُضاف أي نقاط حتى تتطابقا.'
                    : 'Record your actual result. No points are added until both results match.',
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: VSPSpacing.sm),
              _openResultModal(context, currentTeamId),
            ],
          ],
        ),
      );
    }

    if (booking.matchResultStatus == MatchResultStatus.disputed) {
      // A disagreement is not a finalized result and has no standings effect.
      // Either captain may correct their own submission after the match ends.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(VSPSpacing.md),
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic
                  ? 'النتيجتان مختلفتان. لن تُضاف نقاط حتى يتفق قائدا الفريقين.'
                  : 'The two results differ. No points are added until both captains agree.',
              style: const TextStyle(
                color: VSPColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!booking.endTime.isAfter(VSPTimeService.now)) ...[
              const SizedBox(height: VSPSpacing.sm),
              _openResultModal(context, currentTeamId),
            ],
          ],
        ),
      );
    }

    if (booking.matchResultStatus == MatchResultStatus.confirmed) {
      if (!hasCompletedChallengeResult(booking)) {
        return buildStatusBadge(
          isArabic ? 'النتيجة النهائية غير متاحة' : 'Final result unavailable',
          VSPColors.warning,
        );
      }
      if (booking.finalOutcome == null) {
        return buildStatusBadge(
          isArabic ? 'النتيجة غير متاحة حاليًا' : 'Result currently unavailable',
          VSPColors.warning,
        );
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: VSPSpacing.md,
          vertical: VSPSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: VSPColors.accent.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Iconsax.cup_copy,
              color: VSPColors.accent,
              size: 22,
            ),
            const SizedBox(width: VSPSpacing.sm),
            Expanded(
              child: Text(
                isArabic
                    ? 'تم اعتماد النتيجة. راجع ملف فريقك وسجل مواجهاته.'
                    : 'Result confirmed. View your team profile and match history.',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openTeamProfile(context, currentTeamId),
              child: Text(isArabic ? 'ملف الفريق' : 'Team profile'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
