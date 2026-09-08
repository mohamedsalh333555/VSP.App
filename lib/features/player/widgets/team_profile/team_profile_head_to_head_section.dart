import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';

class TeamProfileHeadToHeadSection extends StatelessWidget {
  final Team team;
  final List<Map<String, dynamic>> headToHeadRecords;

  const TeamProfileHeadToHeadSection({
    super.key,
    required this.team,
    required this.headToHeadRecords,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.status_up_copy, color: VSPColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'سجل المواجهات المباشرة (Head-to-Head)' : 'Head-to-Head History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: VSPSpacing.sm),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: headToHeadRecords.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final rec = headToHeadRecords[index];
            final isTeamA = rec['team_a_id'] == team.id;
            final opponent = isTeamA ? rec['team_b'] : rec['team_a'];
            final opponentName = opponent?['name']?.toString() ?? 'فريق منافس';
            final opponentLogo = opponent?['logo_url']?.toString() ?? '';

            final teamWins = isTeamA ? (rec['team_a_wins'] ?? 0) : (rec['team_b_wins'] ?? 0);
            final opponentWins = isTeamA ? (rec['team_b_wins'] ?? 0) : (rec['team_a_wins'] ?? 0);
            final draws = rec['draws'] ?? 0;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.borderLight),
              ),
              child: Row(
                children: [
                  ShimmerImage(
                    imageUrl: opponentLogo,
                    width: 36,
                    height: 36,
                    borderRadius: 18,
                    errorWidget: const CircleAvatar(
                      radius: 18,
                      backgroundColor: VSPColors.surfaceAlt,
                      child: Icon(Iconsax.people_copy, size: 18, color: VSPColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ضد $opponentName',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'فوز: $teamWins | تعادل: $draws | خسارة: $opponentWins',
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: teamWins > opponentWins
                          ? VSPColors.success.withValues(alpha: 0.15)
                          : VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: teamWins > opponentWins ? VSPColors.success : VSPColors.borderLight,
                      ),
                    ),
                    child: Text(
                      '$teamWins - $opponentWins',
                      style: TextStyle(
                        color: teamWins > opponentWins ? VSPColors.success : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
