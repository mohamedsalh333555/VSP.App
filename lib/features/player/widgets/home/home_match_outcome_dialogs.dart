import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../screens/player_home_screen.dart';
import '../match_result_modal.dart';

/// يعرض نافذة منبثقة لإدخال نتيجة المباراة بعد انتهائها (للكابتن الأول)
void showPostMatchAddResultDialog(BuildContext context, Booking booking, String userId) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
        title: Column(
          children: [
            const Icon(Iconsax.cup_copy, color: VSPColors.warning, size: 36),
            const SizedBox(height: 8),
            Text(
              isArabic ? 'انتهت مباراتك' : 'Match Completed',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isArabic
                  ? 'انتهت مباراتك في ملعب "${booking.stadiumName}". اختر نتيجة المباراة لتحديث ترتيب فريقك بالدوري:'
                  : 'Your match at "${booking.stadiumName}" has ended. Select outcome to update your team league rank:',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => MatchResultModal(
                    booking: booking,
                    submittingTeamId: booking.playerTeamId ?? userId,
                    onConfirm: (outcome, rating, review) async {
                      final provider = Provider.of<BookingProvider>(context, listen: false);
                      await provider.submitMatchResult(
                        bookingId: booking.id,
                        teamId: booking.playerTeamId ?? userId,
                        outcome: outcome,
                        rating: rating,
                        review: review,
                      );
                      if (context.mounted) {
                        VSPFeedback.showSuccess(
                          context,
                          isArabic
                              ? 'تم تسجيل النتيجة بنجاح وفي انتظار تأكيد الخصم.'
                              : 'Result submitted & waiting opponent confirmation.',
                        );
                      }
                    },
                  ),
                );
              },
              child: Text(
                isArabic ? 'تسجيل نتيجة المباراة الآن' : 'Enter Match Result Now',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                isArabic ? 'تخطي للوقت الحالي' : 'Skip for now',
                style: const TextStyle(color: VSPColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// يعرض نافذة منبثقة لتأكيد أو الاعتراض على نتيجة المباراة المسجلة (للكابتن الخصم)
void showPostMatchConfirmResultDialog(BuildContext context, Booking booking, String userId) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final pending = booking.pendingOutcome;
  final currentTeamId = booking.opponentTeamId ?? userId;
  final isHome = currentTeamId == booking.playerTeamId;

  String claimText;
  MatchOutcome agreeOutcome;
  MatchOutcome disputeOutcome;

  if (pending == MatchOutcome.draw) {
    claimText = isArabic ? 'أدخل كابتن الخصم أن المباراة انتهت بالتعادل ' : 'Opponent reported a DRAW ';
    agreeOutcome = MatchOutcome.draw;
    disputeOutcome = isHome ? MatchOutcome.homeWin : MatchOutcome.awayWin;
  } else if ((pending == MatchOutcome.homeWin && !isHome) || (pending == MatchOutcome.awayWin && isHome)) {
    claimText = isArabic ? 'أدخل كابتن الخصم أن فريقه فاز بالمباراة ' : 'Opponent reported THEY WON ';
    agreeOutcome = pending!;
    disputeOutcome = isHome ? MatchOutcome.homeWin : MatchOutcome.awayWin;
  } else {
    claimText = isArabic ? 'أدخل كابتن الخصم أن فريقك هو الفائز ' : 'Opponent reported YOU WON ';
    agreeOutcome = pending!;
    disputeOutcome = isHome ? MatchOutcome.awayWin : MatchOutcome.homeWin;
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
        title: Column(
          children: [
            const Icon(Iconsax.notification_copy, color: VSPColors.accent, size: 36),
            const SizedBox(height: 8),
            Text(
              isArabic ? 'تأكيد نتيجة مباراة التحدي ' : 'Confirm Challenge Match Result ',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              claimText,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isArabic ? 'ملعب: ${booking.stadiumName}' : 'Pitch: ${booking.stadiumName}',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
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
                              isArabic ? 'تم تأكيد النتيجة وتحديث ترتيب الدوري!' : 'Result confirmed & rankings updated!',
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final provider = Provider.of<BookingProvider>(context, listen: false);
                      await provider.submitMatchResult(
                        bookingId: booking.id,
                        teamId: currentTeamId,
                        outcome: disputeOutcome,
                      );
                      if (context.mounted) {
                        VSPFeedback.showWarning(
                          context,
                          isArabic ? 'تم تسجيل النزاع للمراجعة الإدارية ' : 'Dispute recorded for review ',
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
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isArabic ? 'تأجيل' : 'Later', style: const TextStyle(color: VSPColors.textSecondary)),
            ),
          ],
        ),
      );
    },
  );
}
