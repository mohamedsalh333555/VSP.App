import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/team_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../screens/player_home_screen.dart';

/// Team record metrics. Historical 1v1 titles are never current competitions
/// or substitutes for officially verified Team Skills awards.
class TeamStatsHeader extends StatelessWidget {
  final Team team;
  final int membersCount;
  final bool isArabic;

  const TeamStatsHeader({
    super.key,
    required this.team,
    required this.membersCount,
    required this.isArabic,
  });

  static String historicalChampionTitle({required bool isArabic}) =>
      isArabic ? 'إنجاز تاريخي: بطل 1 ضد 1' : 'Historical 1v1 champion';

  static String historicalChampionDescription({required bool isArabic}) =>
      isArabic
          ? 'أحد لاعبي الفريق فاز سابقًا ببطولة 1 ضد 1، وهي ليست بطولة جارية'
          : 'A team member previously won the retired 1v1 tournament';

  static String recordedTitlesLabel({required bool isArabic}) =>
      isArabic ? 'بطولات مسجلة' : 'Recorded titles';

  static String teamPointsExplanation({required bool isArabic}) =>
      isArabic
          ? 'دي نقاط الفريق المسجلة حاليًا. راجع جدول الترتيب لعرض المركز الحالي؛ النتائج المعلقة أو المتنازع عليها مش بالضرورة تكون محسوبة.'
          : 'These are the team’s recorded points. Check current standings for placement; pending or disputed results may not be included.';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 1v1 Champion Banner (if applicable)
        FutureBuilder<bool>(
          future: TeamRepository().has1v1Champion(team.id),
          builder: (context, champSnap) {
            if (champSnap.data == true) {
              return Container(
                margin: const EdgeInsets.only(bottom: VSPSpacing.md),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [VSPColors.warning.withValues(alpha: 0.25), VSPColors.surface],
                  ),
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                  border: Border.all(color: VSPColors.warning, width: 1),
                ),
                child: Row(
                  children: [
                    const SizedBox.shrink(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            historicalChampionTitle(isArabic: isArabic),
                            style: const TextStyle(
                              color: VSPColors.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            historicalChampionDescription(isArabic: isArabic),
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // 2. 4-Metrics Row (Points, Members, Trophies, Wins)
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showEloInfoDialog(context),
                child: _buildStatCard(
                  context,
                  team.points.toString(),
                  isArabic ? 'نقاط الدوري' : l10n.points,
                  showInfoIcon: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(context, membersCount.toString(), l10n.members),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(context, team.championshipsWon.toString(), recordedTitlesLabel(isArabic: isArabic)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(context, team.wins.toString(), l10n.wins),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label, {bool showInfoIcon = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
        color: VSPColors.surface.withValues(alpha: 0.5),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: VSPColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (showInfoIcon)
            const Positioned(
              top: 0,
              left: 4,
              child: Icon(Iconsax.info_circle_copy, size: 12, color: VSPColors.accent),
            ),
        ],
      ),
    );
  }

  void _showEloInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isArabic ? 'نقاط الفريق' : 'Team points',
                style: const TextStyle(color: VSPColors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          teamPointsExplanation(isArabic: isArabic),
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isArabic ? 'إغلاق' : 'Close',
              style: const TextStyle(color: VSPColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.accent,
              foregroundColor: VSPColors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
            ),
            icon: const Icon(Iconsax.chart_copy, size: 16),
            onPressed: () {
              Navigator.pop(context);
              navigateToTeamsStandings(context);
            },
            label: Text(
              isArabic ? '🏆 جدول الترتيب' : '🏆 Standings',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
