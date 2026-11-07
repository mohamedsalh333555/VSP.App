import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';

class TeamProfileStatsGrid extends StatelessWidget {
  final Team team;
  final int totalMembersCount;

  const TeamProfileStatsGrid({
    super.key,
    required this.team,
    required this.totalMembersCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    // Flexible layout for narrow screens and larger accessibility text.
    // Raw trophy counts are intentionally not presented as verified titles.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1.0);
        final columns = constraints.maxWidth >= 520 && scale <= 1.3 ? 4 : 2;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(width: itemWidth, child: _buildStatCard(context, team.wins.toString(), l10n.wins)),
            SizedBox(width: itemWidth, child: _buildStatCard(context, team.draws.toString(), isArabic ? 'تعادل' : 'Draws')),
            SizedBox(width: itemWidth, child: _buildStatCard(context, team.losses.toString(), isArabic ? 'خسارة' : 'Losses')),
            SizedBox(width: itemWidth, child: _buildStatCard(context, totalMembersCount.toString(), l10n.members)),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider),
        color: VSPColors.surface,
      ),
      child: Column(
        children: [
          Semantics(
            label: '$label: $value',
            child: ExcludeSemantics(
              child: Text(
                value,
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
