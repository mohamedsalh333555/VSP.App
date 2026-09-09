import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/models/user_model.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../l10n/app_localizations.dart';

/// Displays the team members section inside [CreateTeamSheet].
///
/// Shows:
/// - A header with the current count and action buttons (paste / add).
/// - A chip grid when [members] is non-empty, or a styled empty-state placeholder.
///
/// [onAddMember] opens the add-player flow;
/// [onPasteWhatsApp] opens the roster-import dialog;
/// [onRemoveMember] removes the given member from the list.
class CreateTeamMembersSection extends StatelessWidget {
  final List<UserModel> members;
  final VoidCallback onAddMember;
  final VoidCallback onPasteWhatsApp;
  final ValueChanged<UserModel> onRemoveMember;

  const CreateTeamMembersSection({
    super.key,
    required this.members,
    required this.onAddMember,
    required this.onPasteWhatsApp,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                l10n.teamMembersHeader(members.length + 1, 12),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: VSPColors.textSecondary,
                    ),
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onPasteWhatsApp,
                  icon: const Icon(Iconsax.copy_copy, size: 16, color: VSPColors.accent),
                  label: Text(
                    isArabic ? 'لصق واتساب ' : 'Paste WhatsApp ',
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAddMember,
                  icon: const Icon(Iconsax.add_circle_copy, size: 18, color: VSPColors.accent),
                  label: Text(
                    l10n.addMemberBtn,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: VSPSpacing.sm),
        if (members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: VSPSpacing.xl),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(color: VSPColors.divider),
            ),
            child: Column(
              children: [
                Icon(
                  Iconsax.user_add_copy,
                  color: VSPColors.textSecondary.withValues(alpha: 0.1),
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.noMembersAddedYet,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: VSPColors.textSecondary.withValues(alpha: 0.3),
                      ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(VSPSpacing.sm),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: members.map((member) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShimmerImage(
                        imageUrl: member.profileImageUrl ?? '',
                        width: 28,
                        height: 28,
                        borderRadius: VSPRadius.full,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        member.name ?? 'Player',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => onRemoveMember(member),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Iconsax.close_circle_copy,
                            size: 14,
                            color: VSPColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
