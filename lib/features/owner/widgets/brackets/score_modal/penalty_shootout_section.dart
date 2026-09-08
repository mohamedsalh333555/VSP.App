import 'package:flutter/material.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../../data/models.dart';
import 'score_counter_column.dart';

class PenaltyShootoutSection extends StatelessWidget {
  final TournamentMatch match;
  final int homePenalties;
  final int awayPenalties;
  final String? selectedWinnerId;
  final VoidCallback onIncrementHome;
  final VoidCallback onDecrementHome;
  final VoidCallback onIncrementAway;
  final VoidCallback onDecrementAway;
  final ValueChanged<String> onSelectWinner;

  const PenaltyShootoutSection({
    super.key,
    required this.match,
    required this.homePenalties,
    required this.awayPenalties,
    required this.selectedWinnerId,
    required this.onIncrementHome,
    required this.onDecrementHome,
    required this.onIncrementAway,
    required this.onDecrementAway,
    required this.onSelectWinner,
  });

  Widget _buildPenaltyWinnerButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent : VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: isSelected ? VSPColors.accent : VSPColors.divider, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VSPColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'ركلات الترجيح / Penalties Shootout' : 'Penalty Shootout (Knockout Draw)',
            style: const TextStyle(color: VSPColors.warning, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            isArabic
                ? 'أدخل أهداف ركلات الترجيح وحدد الفريق المتأهل:'
                : 'Enter penalty goals & select advancing team:',
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ScoreCounterColumn(
                  teamName: '${match.homeTeamName ?? "Home"} (ركلات)',
                  score: homePenalties,
                  onIncrement: onIncrementHome,
                  onDecrement: onDecrementHome,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ScoreCounterColumn(
                  teamName: '${match.awayTeamName ?? "Away"} (ركلات)',
                  score: awayPenalties,
                  onIncrement: onIncrementAway,
                  onDecrement: onDecrementAway,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPenaltyWinnerButton(
                  label: match.homeTeamName ?? 'Home',
                  isSelected: selectedWinnerId == match.homeTeamId,
                  onTap: () {
                    if (match.homeTeamId != null) onSelectWinner(match.homeTeamId!);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPenaltyWinnerButton(
                  label: match.awayTeamName ?? 'Away',
                  isSelected: selectedWinnerId == match.awayTeamId,
                  onTap: () {
                    if (match.awayTeamId != null) onSelectWinner(match.awayTeamId!);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
