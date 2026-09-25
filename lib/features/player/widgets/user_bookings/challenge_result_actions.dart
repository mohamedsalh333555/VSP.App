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

/// Actions and status badges for challenge bookings when a match has completed.
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
      } else if (outcome == MatchOutcome.homeWin) {
        final isWon = isHome;
        return buildStatusBadge(isWon ? l10n.win : l10n.loss, isWon ? VSPColors.warning : VSPColors.error);
      } else if (outcome == MatchOutcome.awayWin) {
        final isWon = isAway;
        return buildStatusBadge(isWon ? l10n.win : l10n.loss, isWon ? VSPColors.warning : VSPColors.error);
      }
      return buildStatusBadge(l10n.completed, VSPColors.textSecondary);
    } else if (booking.matchResultStatus == MatchResultStatus.disputed) {
      return buildStatusBadge(l10n.disputed, VSPColors.warning);
    } else if (booking.matchResultStatus == MatchResultStatus.waitingOpponent) {
      return buildStatusBadge(l10n.waitingOpponent, VSPColors.warning);
    } else if (booking.endTime.isBefore(DateTime.now())) {
      return buildStatusBadge(l10n.submitResult, VSPColors.warning);
    }

    return const SizedBox.shrink();
  }

  static Widget buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: 6),
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

  Widget _buildAddResultButton(BuildContext context, String currentTeamId, {bool isPrimaryPopping = false}) {
    final l10n = AppLocalizations.of(context)!;
    return VSPAnimatedButton(
      text: l10n.addResult,
      color: isPrimaryPopping ? VSPColors.warning : VSPColors.accent,
      textColor: isPrimaryPopping ? Colors.black : VSPColors.textPrimary,
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => MatchResultModal(
            booking: booking,
            submittingTeamId: currentTeamId,
            onConfirm: (outcome, rating, review) async {
              final provider = Provider.of<BookingProvider>(context, listen: false);

              final success = await provider.submitMatchResult(
                bookingId: booking.id,
                teamId: currentTeamId,
                outcome: outcome,
                rating: rating,
                review: review,
              );

              if (!context.mounted) return;

              if (success) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.resultSuccess),
                    backgroundColor: VSPColors.accent,
                  ),
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

    final isHome = currentTeamId == booking.playerTeamId;

    // 1. No result entered yet
    if (booking.matchResultStatus == MatchResultStatus.noResult) {
      return _buildAddResultButton(context, currentTeamId, isPrimaryPopping: true);
    }

    // 2. First captain entered result, waiting for opponent or disputed
    if (booking.matchResultStatus == MatchResultStatus.waitingOpponent ||
        booking.matchResultStatus == MatchResultStatus.disputed) {
      if (booking.resultSubmittedByTeamId == currentTeamId) {
        // Submitting captain: sees waiting state with option to edit
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VSPColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(Iconsax.clock_copy, color: VSPColors.warning, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  booking.matchResultStatus == MatchResultStatus.disputed
                      ? (isArabic ? 'النتيجة قيد النزاع ' : 'Result under dispute ')
                      : (isArabic ? 'في انتظار تأكيد الخصم ' : 'Waiting opponent confirmation '),
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Iconsax.edit_2_copy, size: 14),
                label: Text(
                  isArabic ? 'تعديل' : 'Edit',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => MatchResultModal(
                      booking: booking,
                      submittingTeamId: currentTeamId,
                      onConfirm: (outcome, rating, review) async {
                        final provider = Provider.of<BookingProvider>(context, listen: false);
                        final success = await provider.submitMatchResult(
                          bookingId: booking.id,
                          teamId: currentTeamId,
                          outcome: outcome,
                          rating: rating,
                          review: review,
                        );
                        if (context.mounted && success) {
                          VSPFeedback.showSuccess(
                            context,
                            isArabic
                                ? 'تم تعديل النتيجة وإرسالها للخصم للموافقة '
                                : 'Result updated & sent to opponent ',
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      } else {
        // Opponent captain: sees claimed score, confirms or disputes
        final pending = booking.pendingOutcome;
        String claimText;
        MatchOutcome agreeOutcome;
        MatchOutcome disputeOutcome;

        if (pending == MatchOutcome.draw) {
          claimText = isArabic ? 'أدخل الخصم أن المباراة انتهت بالتعادل ' : 'Opponent reported a DRAW ';
          agreeOutcome = MatchOutcome.draw;
          disputeOutcome = isHome ? MatchOutcome.homeWin : MatchOutcome.awayWin;
        } else if ((pending == MatchOutcome.homeWin && !isHome) ||
            (pending == MatchOutcome.awayWin && isHome)) {
          claimText = isArabic ? 'أدخل الخصم أن فريقه فاز بالمباراة ' : 'Opponent reported THEY WON ';
          agreeOutcome = pending!;
          disputeOutcome = isHome ? MatchOutcome.homeWin : MatchOutcome.awayWin;
        } else {
          claimText = isArabic ? 'أدخل الخصم أن فريقك هو الفائز ' : 'Opponent reported YOU WON ';
          agreeOutcome = pending!;
          disputeOutcome = isHome ? MatchOutcome.awayWin : MatchOutcome.homeWin;
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VSPColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: VSPColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: VSPColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.clock_copy, color: VSPColors.warning, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isArabic
                            ? ' يرجى تأكيد النتيجة خلال 24 ساعة؛ التجاهل يؤدي للاعتماد التلقائي وخصم 5 نقاط لعب نظيف.'
                            : ' Please confirm score within 24h. Inaction auto-approves result & deducts 5 Fair-Play pts.',
                        style: const TextStyle(
                            color: VSPColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                claimText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VSPColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () async {
                        final provider = Provider.of<BookingProvider>(context, listen: false);
                        await provider.submitMatchResult(
                          bookingId: booking.id,
                          teamId: currentTeamId,
                          outcome: agreeOutcome,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: VSPColors.accent,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 6),
                              content: Text(
                                isArabic
                                    ? 'تم تأكيد النتيجة وتحديث ترتيب الدوري!'
                                    : 'Result confirmed & rankings updated!',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                              action: SnackBarAction(
                                label: isArabic ? '🏆 جدول الترتيب' : '🏆 Standings',
                                textColor: Colors.black,
                                onPressed: () => navigateToTeamsStandings(context),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        isArabic ? ' تأكيد النتيجة' : ' Confirm',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VSPColors.error,
                        side: const BorderSide(color: VSPColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () async {
                        final provider = Provider.of<BookingProvider>(context, listen: false);
                        await provider.submitMatchResult(
                          bookingId: booking.id,
                          teamId: currentTeamId,
                          outcome: disputeOutcome,
                        );
                        if (context.mounted) {
                          VSPFeedback.showWarning(
                            context,
                            isArabic
                                ? 'تم تسجيل النزاع للمراجعة الإدارية '
                                : 'Dispute recorded for review ',
                          );
                        }
                      },
                      child: Text(
                        isArabic ? ' اعتراض' : ' Dispute',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    }

    // 3. Match result confirmed: show action card to view team standing in the leaderboard
    if (booking.matchResultStatus == MatchResultStatus.confirmed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'تم اعتماد النتيجة رسمياً' : 'Result Officially Confirmed',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic ? 'تم تحديث نقاط وترتيب فريقك في الدوري' : 'Team points & ranking updated',
                    style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.9), fontSize: 11),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
              ),
              icon: const Icon(Iconsax.chart_copy, size: 14),
              label: Text(
                isArabic ? 'الترتيب' : 'Standings',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              onPressed: () => navigateToTeamsStandings(context),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
