import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

/// Card widget displaying the live standings table for matchup teams.
class MatchupStandingsTable extends StatelessWidget {
  final List<MatchupStandingsItem> standings;

  const MatchupStandingsTable({
    super.key,
    required this.standings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.borderLight),
      ),
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Iconsax.ranking_copy, color: VSPColors.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'جدول ترتيب المواجهة الحية',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'حساب النقاط: (فوز = 3 نقاط | تعادل = 1 نقطة)',
            style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
          ),
          const Divider(color: VSPColors.divider, height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: standings.length,
            separatorBuilder: (_, __) => const Divider(color: VSPColors.surfaceAlt, height: 12),
            itemBuilder: (context, index) {
              final item = standings[index];
              final isLeader = index == 0 && item.points > 0;

              return Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isLeader ? VSPColors.accent : VSPColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isLeader ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.teamName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'لعب: ${item.matchesPlayed} | ف: ${item.wins} | ت: ${item.draws} | خ: ${item.losses}',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.points} نقطة',
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
