import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../services/matchup_dashboard_service.dart';

/// Displays chronological timeline of completed matchup match results.
class MatchupResultsTimeline extends StatelessWidget {
  final List<MatchupResult> results;
  final List<MatchupTeam> teams;

  const MatchupResultsTimeline({
    super.key,
    required this.results,
    required this.teams,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(VSPSpacing.lg),
        alignment: Alignment.center,
        child: Text(
          isArabic ? 'لم تُسجل أي مباريات في هذه المواجهة بعد' : 'No matches have been recorded in this matchup yet',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
        ),
      );
    }

    final reversedResults = results.reversed.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'سجل مباريات الجلسة (${results.length})' : 'Session match history (${results.length})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reversedResults.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final result = reversedResults[index];
            final tA = teams.firstWhere(
              (t) => t.teamId == result.teamAId,
              orElse: () => MatchupTeam(
                id: '',
                bookingId: '',
                teamId: result.teamAId,
                teamName: isArabic ? 'فريق أ' : 'Team A',
                addedByUserId: '',
                joinedAt: DateTime.now(),
              ),
            );
            final tB = teams.firstWhere(
              (t) => t.teamId == result.teamBId,
              orElse: () => MatchupTeam(
                id: '',
                bookingId: '',
                teamId: result.teamBId,
                teamName: isArabic ? 'فريق ب' : 'Team B',
                addedByUserId: '',
                joinedAt: DateTime.now(),
              ),
            );

            final presentation = MatchupDashboardService.getOutcomePresentation(
              outcome: result.outcome,
              teamAName: tA.teamName,
              teamBName: tB.teamName,
              isArabic: isArabic,
            );

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.activity_copy, color: VSPColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${tA.teamName} ${isArabic ? 'ضد' : 'vs'} ${tB.teamName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: presentation.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      presentation.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: presentation.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
