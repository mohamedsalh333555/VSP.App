import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Section rendering active team members registered on VSP with selection checkboxes.
class RosterTeamMembersSection extends StatelessWidget {
  final List<Map<String, String>> teamMembers;
  final List<String> selectedPlayerIds;
  final String captainPhone;
  final bool canEdit;
  final bool isArabic;
  final ValueChanged<String> onTogglePlayer;

  const RosterTeamMembersSection({
    super.key,
    required this.teamMembers,
    required this.selectedPlayerIds,
    required this.captainPhone,
    required this.canEdit,
    required this.isArabic,
    required this.onTogglePlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'لاعبو الفريق (عبر التطبيق)' : 'Team Players (In App)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${selectedPlayerIds.length} ${isArabic ? "محدد" : "selected"}',
                style: const TextStyle(
                  color: VSPColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: VSPSpacing.sm),

        if (teamMembers.isEmpty)
          Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.md),
            ),
            child: Text(
              isArabic
                  ? 'لا يوجد أعضاء آخرين في الفريق، يمكنك إضافة ضيوف بالأسفل.'
                  : 'No other team members found, you can add guest players below.',
              style: const TextStyle(color: VSPColors.textSecondary),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: teamMembers.length,
            itemBuilder: (context, index) {
              final member = teamMembers[index];
              final uid = member['uid'] ?? '';
              final name = member['name'] ?? 'Player';
              final phone = member['phone'] ?? '';
              final position = member['position'] ?? '';
              final isSelected = selectedPlayerIds.contains(uid);
              final isCaptain = phone.isNotEmpty && phone == captainPhone;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? VSPColors.accent.withValues(alpha: 0.1) : VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(
                    color: isSelected ? VSPColors.accent : VSPColors.divider,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  activeColor: VSPColors.accent,
                  checkColor: Colors.black,
                  onChanged: canEdit ? (_) => onTogglePlayer(uid) : null,
                  title: Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : VSPColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (isCaptain) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isArabic ? 'كابتن ' : 'Captain ',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    position.isNotEmpty ? position : (isArabic ? 'لاعب كرة قدم' : 'Footballer'),
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  secondary: CircleAvatar(
                    backgroundColor: VSPColors.surfaceAlt,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
