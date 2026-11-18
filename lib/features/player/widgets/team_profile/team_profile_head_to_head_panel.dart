import 'package:flutter/material.dart';
import '../../../../core/ui/vsp_ui.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import 'team_profile_head_to_head_section.dart';

/// Presents the read status independently of the last cached rows.
///
/// In particular, stale matchups cannot mask an in-flight request or a failed
/// refresh. A completed empty response is verified emptiness, not an error.
class TeamProfileHeadToHeadPanel extends StatelessWidget {
  final Team team;
  final List<Map<String, dynamic>> headToHeadRecords;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;

  const TeamProfileHeadToHeadPanel({
    super.key,
    required this.team,
    required this.headToHeadRecords,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // An in-flight request is never a verified result, even when the caller
    // still holds records from an earlier read.
    if (isLoading) {
      return VSPStateView(
        state: VSPUiState.loading,
        title: isArabic
            ? 'جارٍ تحميل سجل المواجهات'
            : 'Loading match history',
        message: isArabic
            ? 'نحدّث نتائج الفريق السابقة.'
            : 'Updating the team’s previous results.',
      );
    }

    // A failed request has unknown results, not an empty/previous record.
    if (hasError) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(VSPSpacing.md),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.card),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Column(
          children: [
            Text(
              isArabic
                  ? 'تعذر تحميل سجل المواجهات. لا يتم عرض السجل كأنه فارغ.'
                  : 'Match history could not be loaded. It is not being shown as empty.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VSPColors.textSecondary),
            ),
            const SizedBox(height: VSPSpacing.sm),
            TextButton(
              onPressed: onRetry,
              child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
            ),
          ],
        ),
      );
    }

    return TeamProfileHeadToHeadSection(
      team: team,
      headToHeadRecords: headToHeadRecords,
    );
  }
}
