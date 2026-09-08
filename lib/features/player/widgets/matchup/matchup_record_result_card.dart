import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Card widget with form inputs to record a new matchup match result.
class MatchupRecordResultCard extends StatelessWidget {
  final List<MatchupTeam> teams;
  final String? selectedTeamAId;
  final String? selectedTeamBId;
  final String selectedOutcome;
  final bool isSubmitting;
  final ValueChanged<String?> onTeamAChanged;
  final ValueChanged<String?> onTeamBChanged;
  final ValueChanged<String> onOutcomeChanged;
  final VoidCallback? onSubmit;

  const MatchupRecordResultCard({
    super.key,
    required this.teams,
    required this.selectedTeamAId,
    required this.selectedTeamBId,
    required this.selectedOutcome,
    required this.isSubmitting,
    required this.onTeamAChanged,
    required this.onTeamBChanged,
    required this.onOutcomeChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (teams.length < 2) return const SizedBox.shrink();

    final teamA = teams.firstWhere(
      (t) => t.teamId == selectedTeamAId,
      orElse: () => teams[0],
    );
    final teamB = teams.firstWhere(
      (t) => t.teamId == selectedTeamBId,
      orElse: () => teams[1],
    );

    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Iconsax.direct_up_copy, color: VSPColors.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'تسجيل نتيجة مباراة جديدة',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Team Selection Pickers
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedTeamAId,
                  dropdownColor: VSPColors.surfaceAlt,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'الفريق الأول',
                    labelStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: VSPColors.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: teams.map((t) => DropdownMenuItem(value: t.teamId, child: Text(t.teamName))).toList(),
                  onChanged: onTeamAChanged,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('VS', style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedTeamBId,
                  dropdownColor: VSPColors.surfaceAlt,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'الفريق الثاني',
                    labelStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: VSPColors.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: teams.map((t) => DropdownMenuItem(value: t.teamId, child: Text(t.teamName))).toList(),
                  onChanged: onTeamBChanged,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Outcome Selector Chips
          const Text('النتيجة:', style: TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildOutcomeChip(
                  label: 'فوز ${teamA.teamName}',
                  value: 'team_a_win',
                  isSelected: selectedOutcome == 'team_a_win',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildOutcomeChip(
                  label: 'تعادل',
                  value: 'draw',
                  isSelected: selectedOutcome == 'draw',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildOutcomeChip(
                  label: 'فوز ${teamB.teamName}',
                  value: 'team_b_win',
                  isSelected: selectedOutcome == 'team_b_win',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          PrimaryButton(
            text: 'تسجيل النتيجة واعتماد الترتيب',
            onPressed: isSubmitting ? null : onSubmit,
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeChip({
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => onOutcomeChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent : VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? VSPColors.accent : VSPColors.borderLight),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
