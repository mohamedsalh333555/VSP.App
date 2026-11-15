import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

enum ChallengeNonPlayedReportState { notReported, excluded, restored }

/// Sanitized caller-scoped report status only; NEVER holds the opponent's
/// selected outcome, another captain's appeal reason or admin review notes.
class ChallengeNonPlayedReportStatus {
  final ChallengeNonPlayedReportState state;
  final bool underReview;
  final bool myAppealSubmitted;

  const ChallengeNonPlayedReportStatus({
    required this.state,
    this.underReview = false,
    this.myAppealSubmitted = false,
  });

  bool get isExcluded => state == ChallengeNonPlayedReportState.excluded;
  bool get isRestored => state == ChallengeNonPlayedReportState.restored;

  /// An authenticated 'reported: false' is a trusted no-report response.
  /// An absent, failed, unauthorized or malformed response is NOT proof
  /// that no report exists. The caller must keep reportLookupRequired true
  /// and hide outcome actions until a valid response is received.
  static ChallengeNonPlayedReportStatus? fromScopedRpc(Object? raw) {
    if (raw is! Map || raw['success'] != true) return null;
    if (raw['reported'] == false) {
      return const ChallengeNonPlayedReportStatus(
        state: ChallengeNonPlayedReportState.notReported,
      );
    }
    if (raw['reported'] != true) return null;
    final state = switch (raw['state']) {
      'excluded' => ChallengeNonPlayedReportState.excluded,
      'restored' => ChallengeNonPlayedReportState.restored,
      _ => null,
    };
    if (state == null) return null;
    return ChallengeNonPlayedReportStatus(
      state: state,
      underReview: state == ChallengeNonPlayedReportState.excluded &&
          raw['under_review'] == true,
      myAppealSubmitted: raw['my_appeal_submitted'] == true,
    );
  }
}

/// Optional UI for the server-backed owner non-played-match reporting flow.
/// Only render when the authenticated, scoped RPC returned this status.
class ChallengeNonPlayedReportBanner extends StatelessWidget {
  final ChallengeNonPlayedReportStatus status;

  const ChallengeNonPlayedReportBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final excluded = status.isExcluded;
    final title = excluded
        ? (isArabic
            ? 'المباراة مستبعدة بسبب بلاغ عدم اللعب'
            : 'Match excluded: reported not played')
        : (isArabic
            ? 'تمت استعادة المباراة بعد المراجعة'
            : 'Match restored after review');
    final description = excluded && status.underReview
        ? (isArabic
            ? 'بلاغ قيد المراجعة. المباراة خارج ترتيب الفريقين حتى صدور القرار.'
            : 'Report under review. The match remains outside both teams’ standings.')
        : excluded
            ? (isArabic
                ? 'لن تُحتسب نقاط لهذه المباراة أثناء الاستبعاد.'
                : 'No ranking points count for this match while excluded.')
            : (isArabic
                ? 'تم إلغاء الاستبعاد. تُعرض النتيجة والترتيب حسب حالة المباراة.'
                : 'Exclusion was lifted. Result and standings follow the match status.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: const TextStyle(color: VSPColors.textPrimary,
                fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: VSPSpacing.xs),
          Text(description,
            style: const TextStyle(color: VSPColors.textSecondary,
                fontSize: 12)),
        ],
      ),
    );
  }
}
