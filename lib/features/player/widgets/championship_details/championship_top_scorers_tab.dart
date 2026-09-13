import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// تبويب ترتيب هدافي البطولة مع تكريم المراتب الثلاث الأولى
class ChampionshipTopScorersTab extends StatelessWidget {
  final String championshipId;

  const ChampionshipTopScorersTab({super.key, required this.championshipId});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: TournamentRepository().getTopScorersForChampionship(championshipId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final scorers = snapshot.data ?? [];
        if (scorers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.award_copy, color: VSPColors.textSecondary, size: 40),
                const SizedBox(height: 12),
                Text(
                  isArabic ? 'لم يتم تسجيل أهداف بعد في هذه البطولة' : 'No goals recorded yet in this tournament',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(VSPSpacing.md),
          itemCount: scorers.length,
          itemBuilder: (context, index) {
            final item = scorers[index];
            final rank = index + 1;
            final String name = item['name'] ?? '';
            final String team = item['team'] ?? '';
            final int goals = item['goals'] as int? ?? 0;

            Color rankColor = VSPColors.surfaceAlt;
            String rankEmoji = '#';
            if (rank == 1) {
              rankColor = VSPColors.accent;
              rankEmoji = '#1';
            } else if (rank == 2) {
              rankColor = VSPColors.accent.withValues(alpha: 0.7);
              rankEmoji = '#2';
            } else if (rank == 3) {
              rankColor = VSPColors.accent.withValues(alpha: 0.5);
              rankEmoji = '#3';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: rankColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        rankEmoji,
                        style: TextStyle(
                          color: rank <= 3 ? rankColor : VSPColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: rank <= 3 ? 16 : 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (team.isNotEmpty && team != 'فريق غير محدد') ...[
                          const SizedBox(height: 2),
                          Text(
                            team,
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '$goals ${isArabic ? "أهداف" : "goals"}',
                          style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
