import 'package:flutter/material.dart';
import '../../../../core/repositories/booking/challenge_captain_private_submission_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Read-only, captain-scoped acknowledgement. No opponent result, audit
/// details, timestamps or account identifiers are displayed here.
class ChallengeOwnSubmissionLabel extends StatelessWidget {
  final ChallengeCaptainSubmission? submission;
  final bool isHomeTeam;

  const ChallengeOwnSubmissionLabel({
    super.key,
    required this.submission,
    required this.isHomeTeam,
  });

  @override
  Widget build(BuildContext context) {
    final data = submission;
    if (data == null) return const SizedBox.shrink();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (!data.submitted) {
      return Text(
        isArabic ? 'لم تسجل نتيجتك بعد.' : 'You have not submitted your result.',
        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
      );
    }
    final selected = data.myOutcome;
    if (selected == null) return const SizedBox.shrink();
    final myWin = (selected == ChallengeCaptainOutcome.homeWin && isHomeTeam) ||
        (selected == ChallengeCaptainOutcome.awayWin && !isHomeTeam);
    final resultLabel = selected == ChallengeCaptainOutcome.draw
        ? (isArabic ? 'تعادل' : 'Draw')
        : myWin
            ? (isArabic ? 'فوز' : 'Win')
            : (isArabic ? 'خسارة' : 'Loss');
    return Text(
      isArabic
          ? 'النتيجة التي سجلتها: $resultLabel'
          : 'Your submitted result: $resultLabel',
      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
    );
  }
}
