import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../screens/player_home_screen.dart';

/// Header section displaying team monthly ranking & performance metrics (Points, Members, Trophies, Wins).
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4-Metrics Row (Monthly Points, Members, Trophies, Wins)
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showRankingInfoDialog(context),
                child: _buildStatCard(
                  context,
                  team.points.toString(),
                  isArabic ? 'نقاط الترتيب' : l10n.points,
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
              child: _buildStatCard(context, team.championshipsWon.toString(), l10n.trophies),
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
        border: Border.all(color: VSPColors.divider),
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
              child: Icon(Iconsax.info_circle_copy, size: 12, color: VSPColors.textSecondary),
            ),
        ],
      ),
    );
  }

  void _showRankingInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Iconsax.cup_copy, color: VSPColors.textSecondary, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isArabic ? 'الترتيب الشهري بالمحافظة' : 'Monthly Governorate Ranking',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'يعتمد الترتيب الشهري على نظام نقاط كرة القدم داخل محافظتك فقط: الفوز 3 نقاط، التعادل نقطة واحدة، والخسارة 0 — ويتصفر أول كل شهر مع حفظ التاريخ، والمركز الأول يحصل على ساعة ملعب مجانية من VSP.'
              : 'Monthly ranking uses classic football points inside your governorate: Win = 3 pts, Draw = 1 pt, Loss = 0. Resets monthly with history saved; #1 wins 1 free pitch hour funded by VSP.',
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
              foregroundColor: Colors.black,
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
