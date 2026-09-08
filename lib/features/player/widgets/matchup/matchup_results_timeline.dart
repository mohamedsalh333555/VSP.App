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
    if (results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(VSPSpacing.lg),
        alignment: Alignment.center,
        child: const Text(
          'لم تُسجل أي مباريات في هذه المواجهة بعد',
          style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجل مباريات الجلسة (${results.length})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: results.reversed.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final result = results.reversed.toList()[index];
            final tA = teams.firstWhere(
              (t) => t.teamId == result.teamAId,
              orElse: () => MatchupTeam(
                id: '',
                bookingId: '',
                teamId: result.teamAId,
                teamName: 'فريق أ',
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
                teamName: 'فريق ب',
                addedByUserId: '',
                joinedAt: DateTime.now(),
              ),
            );

            final presentation = MatchupDashboardService.getOutcomePresentation(
              outcome: result.outcome,
              teamAName: tA.teamName,
              teamBName: tB.teamName,
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
                      '${tA.teamName} ضد ${tB.teamName}',
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
