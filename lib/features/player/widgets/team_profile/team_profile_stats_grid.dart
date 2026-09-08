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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatCard(context, team.points.toString(), l10n.points),
        _buildStatCard(context, totalMembersCount.toString(), l10n.members),
        _buildStatCard(context, team.championshipsWon.toString(), l10n.trophies),
        _buildStatCard(context, team.wins.toString(), l10n.wins),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
        color: VSPColors.surface.withValues(alpha: 0.5),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
