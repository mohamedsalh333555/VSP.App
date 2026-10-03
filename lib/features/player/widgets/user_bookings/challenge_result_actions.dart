import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/vsp_animated_button.dart';
import '../../screens/player_home_screen.dart';
import '../match_result_modal.dart';

/// Challenge result flow: both captains submit independently.
/// The match is finalized only when both submissions match.
class ChallengeResultActions extends StatelessWidget {
  final Booking booking;
  final String? myTeamId;

  const ChallengeResultActions({
    super.key,
    required this.booking,
    this.myTeamId,
  });

  static Widget buildChallengeStatusBadge(
    BuildContext context, {
    required Booking booking,
    required String? myTeamId,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final currentTeamId = myTeamId ?? booking.playerTeamId;
    if (currentTeamId == null) return const SizedBox.shrink();

    final isHome = currentTeamId == booking.playerTeamId;
    final isAway = currentTeamId == booking.opponentTeamId;
    if (!isHome && !isAway) return const SizedBox.shrink();

    if (booking.matchResultStatus == MatchResultStatus.confirmed) {
      final outcome = booking.finalOutcome;
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
      return buildStatusBadge(
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'في انتظار تطابق النتيجة'
            : 'Waiting for matching result',
        VSPColors.warning,
      );
    }

    if (booking.endTime.isBefore(DateTime.now())) {
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
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return VSPAnimatedButton(
      text: isArabic ? 'تسجيل نتيجتي' : 'Record my result',
      color: VSPColors.accent,
      textColor: Colors.black,
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

              if (!context.mounted) return;
              Navigator.of(dialogContext).pop();

              if (success) {
                VSPFeedback.showSuccess(
                  context,
                  isArabic
                      ? 'تم تسجيل نتيجتك. لن تُعتمد المباراة إلا عند تطابق النتيجتين.'
                      : 'Your result was recorded. The match is finalized only when both results match.',
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.errorMessage ?? l10n.resultFailed),
                    backgroundColor: VSPColors.error,
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final currentTeamId = myTeamId ?? booking.playerTeamId;
    if (currentTeamId == null) return const SizedBox.shrink();

    if (booking.matchResultStatus == MatchResultStatus.noResult) {
      return _openResultModal(context, currentTeamId);
    }

    if (booking.matchResultStatus == MatchResultStatus.waitingOpponent) {
      final submittedByMe =
          booking.resultSubmittedByTeamId == currentTeamId;
      final pending = booking.pendingOutcome;

      String outcomeText(MatchOutcome? outcome) {
        if (outcome == MatchOutcome.draw) {
          return isArabic ? 'تعادل' : 'Draw';
        }
        if (outcome == null) {
          return isArabic ? 'لم تُسجل نتيجة بعد' : 'No result yet';
        }

        final myWin =
            (outcome == MatchOutcome.homeWin &&
                currentTeamId == booking.playerTeamId) ||
            (outcome == MatchOutcome.awayWin &&
                currentTeamId == booking.opponentTeamId);

        return isArabic
            ? (myWin ? 'فوز فريقي' : 'فوز الفريق المنافس')
            : (myWin ? 'My team won' : 'Opponent won');
      }

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
                    submittedByMe
                        ? (isArabic
                            ? 'تم تسجيل نتيجتك. في انتظار نتيجة الفريق المنافس.'
                            : 'Your result is recorded. Waiting for the opponent.')
                        : (isArabic
                            ? 'الفريق المنافس سجل: ${outcomeText(pending)}'
                            : 'Opponent recorded: ${outcomeText(pending)}'),
                    style: const TextStyle(
                      color: VSPColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (!submittedByMe) ...[
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

    if (booking.matchResultStatus == MatchResultStatus.confirmed) {
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
                    ? 'تم اعتماد النتيجة وتحديث ترتيب الفرق.'
                    : 'Result confirmed and team standings updated.',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: () => navigateToTeamsStandings(context),
              child: Text(isArabic ? 'الترتيب' : 'Standings'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
