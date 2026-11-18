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

  /// Normalize aggregates relative to the displayed team. A mirrored
  /// record must compare equal to its original (W/D/L, not A/B position).
  static (int?, int?, int?) _countsForTeam(
    String teamId,
    Map<String, dynamic> row,
  ) {
    final isA = row['team_a_id'] == teamId;
    return (
      validCount(isA ? row['team_a_wins'] : row['team_b_wins']),
      validCount(row['draws']),
      validCount(isA ? row['team_b_wins'] : row['team_a_wins']),
    );
  }

  /// A repeated row for the same opponent must not create duplicate cards.
  /// If two rows disagree, neither can be trusted: hide that opponent rather
  /// than silently selecting the first or showing contradictory results.
  /// Unrelated, self-play and incomplete team identifiers are also excluded.
  static List<Map<String, dynamic>> recordsForTeam(
    String teamId,
    Iterable<Map<String, dynamic>> records,
  ) {
    final id = teamId.trim();
    if (id.isEmpty) return const [];
    final byOpponent = <String, Map<String, dynamic>>{};
    final conflicts = <String>{};
    for (final row in records) {
      final a = row['team_a_id'];
      final b = row['team_b_id'];
      String? opponentId;
      if (a == id && b is String && b.trim().isNotEmpty && b != id) {
        opponentId = b;
      } else if (b == id && a is String &&
          a.trim().isNotEmpty && a != id) {
        opponentId = a;
      }
      if (opponentId == null || conflicts.contains(opponentId)) continue;
      final previous = byOpponent[opponentId];
      if (previous == null) {
        byOpponent[opponentId] = row;
      } else if (_countsForTeam(id, previous) != _countsForTeam(id, row)) {
        byOpponent.remove(opponentId);
        conflicts.add(opponentId);
      }
    }
    return byOpponent.values.toList(growable: false);
  }

  /// Aggregate only authenticated head-to-head counters belonging to this
  /// team. An invalid response, duplicate opponent, or unplayed zero row must
  /// never be presented as progress or a ranking movement.
  static ({int wins, int draws, int losses, int opponents})? recordedTotals(
    String teamId,
    Iterable<Map<String, dynamic>> records,
  ) {
    final seenOpponents = <String>{};
    var wins = 0, draws = 0, losses = 0;
    for (final row in recordsForTeam(teamId, records)) {
      final isHome = row['team_a_id'] == teamId;
      final opponent = isHome ? row['team_b_id'] : row['team_a_id'];
      if (opponent is! String || seenOpponents.contains(opponent)) continue;
      final w = validCount(isHome ? row['team_a_wins'] : row['team_b_wins']);
      final l = validCount(isHome ? row['team_b_wins'] : row['team_a_wins']);
      final d = validCount(row['draws']);
      if (w == null || l == null || d == null || w + l + d == 0) continue;
      seenOpponents.add(opponent);
      wins += w;
      losses += l;
      draws += d;
    }
    if (seenOpponents.isEmpty) return null;
    return (wins: wins, draws: draws, losses: losses,
      opponents: seenOpponents.length);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final visibleRecords = recordsForTeam(team.id, headToHeadRecords);
    final totals = recordedTotals(team.id, headToHeadRecords);

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
        if (totals != null) ...[
          Text(
            isArabic
                ? 'المواجهات المسجلة: ${totals.wins} فوز • ${totals.draws} تعادل • ${totals.losses} خسارة'
                : 'Recorded matchups: ${totals.wins} W • ${totals.draws} D • ${totals.losses} L',
            style: const TextStyle(
              color: VSPColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          Text(
            isArabic
                ? 'إجمالي المواجهات المباشرة فقط، وليس تغييرًا في الترتيب'
                : 'Head-to-head totals only, not a ranking change',
            style: const TextStyle(
              color: VSPColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: VSPSpacing.sm),
        ],
        if (visibleRecords.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: VSPSpacing.md),
            child: Text(
              headToHeadRecords.isEmpty
                  ? (isArabic
                      ? 'لا توجد مواجهات مسجلة حتى الآن'
                      : 'No recorded matchups yet')
                  : (isArabic
                      ? 'بيانات المواجهات المتاحة غير صالحة للعرض'
                      : 'Available head-to-head records cannot be verified'),
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
                      complete
                          ? (isArabic ? '$teamWins فوز'
                              : (teamWins == 1 ? '1 win' : '$teamWins wins'))
                          : '—',
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
