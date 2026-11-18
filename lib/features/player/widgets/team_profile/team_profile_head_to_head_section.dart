import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../data/models.dart';

/// Aggregate opponent history, not a single-match score or live ranking.
class TeamProfileHeadToHeadSection extends StatelessWidget {
  final Team team;
  final List<Map<String, dynamic>> headToHeadRecords;

  const TeamProfileHeadToHeadSection({
    super.key,
    required this.team,
    required this.headToHeadRecords,
  });

  /// Never invent a 0-0 record when the source omits or corrupts counters.
  static int? validCount(dynamic value) =>
      value is int && value >= 0 ? value : null;

  /// Fail closed if an aggregate row belongs to another team or references
  /// the same team on both sides. A cached/malformed response must not be
  /// presented as this team's confirmed sporting history.
  static List<Map<String, dynamic>> recordsForTeam(
    String teamId,
    Iterable<Map<String, dynamic>> records,
  ) {
    final id = teamId.trim();
    if (id.isEmpty) return const [];
    return records.where((row) {
      final a = row['team_a_id'];
      final b = row['team_b_id'];
      return (a == id && b is String && b.trim().isNotEmpty && b != id) ||
          (b == id && a is String && a.trim().isNotEmpty && a != id);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final visibleRecords = recordsForTeam(team.id, headToHeadRecords);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.status_up_copy, color: VSPColors.accent, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(
              isArabic ? 'إجمالي المواجهات مع الفرق' : 'Head-to-head totals',
              style: Theme.of(context).textTheme.titleLarge,
            )),
          ],
        ),
        const SizedBox(height: VSPSpacing.sm),
        if (visibleRecords.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: VSPSpacing.md),
            child: Text(
              isArabic
                  ? 'بيانات المواجهات المتاحة غير صالحة للعرض'
                  : 'Available head-to-head records cannot be verified',
              style: const TextStyle(color: VSPColors.textSecondary),
            ),
          ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleRecords.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final rec = visibleRecords[index];
            final isTeamA = rec['team_a_id'] == team.id;
            final dynamic opponent = isTeamA ? rec['team_b'] : rec['team_a'];
            final opponentMap = opponent is Map ? opponent : const {};
            final opponentName = opponentMap['name']?.toString().trim();
            final displayName = opponentName == null || opponentName.isEmpty
                ? (isArabic ? 'فريق منافس' : 'Opponent team')
                : opponentName;
            final opponentLogo = opponentMap['logo_url']?.toString() ?? '';

            final teamWins = validCount(isTeamA ? rec['team_a_wins'] : rec['team_b_wins']);
            final opponentWins = validCount(isTeamA ? rec['team_b_wins'] : rec['team_a_wins']);
            final draws = validCount(rec['draws']);
            final complete = teamWins != null && opponentWins != null && draws != null;
            final ahead = complete && teamWins > opponentWins;
            final summary = complete
                ? (isArabic
                    ? 'فوز: $teamWins | تعادل: $draws | خسارة: $opponentWins'
                    : 'Wins: $teamWins | Draws: $draws | Losses: $opponentWins')
                : (isArabic
                    ? 'بيانات المواجهات غير مكتملة'
                    : 'Head-to-head counts unavailable');

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
                          isArabic ? 'ضد $displayName' : 'vs $displayName',
                          style: const TextStyle(color: VSPColors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ahead
                          ? VSPColors.success.withValues(alpha: 0.15)
                          : VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ahead ? VSPColors.success : VSPColors.borderLight,
                      ),
                    ),
                    child: Text(
                      complete ? '$teamWins - $opponentWins' : '—',
                      style: TextStyle(
                        color: ahead ? VSPColors.success : VSPColors.white,
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
