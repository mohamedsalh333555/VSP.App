import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class CheckoutTeamMembersList extends StatelessWidget {
  final List<Map<String, dynamic>> teamMembers;
  final List<String> selectedPlayerIds;
  final bool isLoading;
  final String captainId;
  final ValueChanged<String> onTogglePlayer;

  const CheckoutTeamMembersList({
    super.key,
    required this.teamMembers,
    required this.selectedPlayerIds,
    required this.isLoading,
    required this.captainId,
    required this.onTogglePlayer,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: VSPColors.accent),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أعضاء الفريق المسجلين:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: VSPSpacing.sm),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: teamMembers.length,
          itemBuilder: (context, index) {
            final member = teamMembers[index];
            final memberId = member['id'] as String? ?? '';
            final isSelected = selectedPlayerIds.contains(memberId);
            final isCaptain = memberId == captainId;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(
                  color: isSelected ? VSPColors.accent.withValues(alpha: 0.5) : VSPColors.divider,
                ),
              ),
              child: CheckboxListTile(
                value: isSelected,
                activeColor: VSPColors.accent,
                title: Text(
                  member['name'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: isCaptain
                    ? const Text(
                        'قائد الفريق (إجباري)',
                        style: TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                      )
                    : null,
                secondary: CircleAvatar(
                  radius: 18,
                  backgroundImage: (member['profile_image_url'] != null &&
                          member['profile_image_url'].toString().isNotEmpty)
                      ? NetworkImage(member['profile_image_url'])
                      : null,
                  backgroundColor: VSPColors.surfaceAlt,
                  child: (member['profile_image_url'] == null ||
                          member['profile_image_url'].toString().isEmpty)
                      ? const Icon(Iconsax.user_copy, color: VSPColors.textSecondary, size: 18)
                      : null,
                ),
                onChanged: isCaptain
                    ? null
                    : (val) {
                        onTogglePlayer(memberId);
                      },
              ),
            );
          },
        ),
      ],
    );
  }
}
