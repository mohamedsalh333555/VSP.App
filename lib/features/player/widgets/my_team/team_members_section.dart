import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';

/// Section showing the team roster chips (Captain + active members) with addition/removal controls.
class TeamMembersSection extends StatelessWidget {
  final Team? team;
  final UserModel? captainUser;
  final List<UserModel> teamMembers;
  final bool isLoadingMembers;
  final bool isCaptain;
  final bool isArabic;
  final VoidCallback onAddMember;
  final void Function(UserModel member) onRemoveMember;

  const TeamMembersSection({
    super.key,
    required this.team,
    required this.captainUser,
    required this.teamMembers,
    required this.isLoadingMembers,
    required this.isCaptain,
    required this.isArabic,
    required this.onAddMember,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalCount = 1 + teamMembers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.teamMembersHeader(totalCount, 12),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (isCaptain && totalCount < 12)
              TextButton.icon(
                onPressed: onAddMember,
                icon: const Icon(Iconsax.add_circle_copy, size: 16, color: VSPColors.accent),
                label: Text(
                  l10n.addMember,
                  style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: VSPSpacing.sm),
        if (isLoadingMembers)
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Always render Captain chip first
                _buildCaptainChip(team, captainUser, isArabic),
                ...teamMembers.map((member) => _buildMemberChip(member)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCaptainChip(Team? team, UserModel? currentUser, bool isArabic) {
    final name = team?.captainName ?? currentUser?.name ?? (isArabic ? 'الكابتن' : 'Captain');
    final imgUrl = team?.captainImageUrl ?? currentUser?.profileImageUrl ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(color: VSPColors.accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: VSPColors.accent,
            backgroundImage: imgUrl.isNotEmpty ? NetworkImage(imgUrl) : null,
            child: imgUrl.isEmpty ? const Icon(Iconsax.crown_copy, color: Colors.black, size: 12) : null,
          ),
          const SizedBox(width: VSPSpacing.sm),
          Text(
            name,
            style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: VSPColors.accent,
              borderRadius: BorderRadius.circular(VSPRadius.xs),
            ),
            child: Text(
              isArabic ? 'كابتن' : 'C',
              style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberChip(UserModel user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: VSPColors.surface,
            backgroundImage: (user.profileImageUrl?.isNotEmpty ?? false) ? NetworkImage(user.profileImageUrl!) : null,
            child: (user.profileImageUrl?.isEmpty ?? true)
                ? const Icon(Iconsax.user_copy, color: VSPColors.textSecondary, size: 12)
                : null,
          ),
          const SizedBox(width: VSPSpacing.sm),
          Text(
            user.name ?? 'Player',
            style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (isCaptain && (1 + teamMembers.length) <= 12)
            GestureDetector(
              onTap: () => onRemoveMember(user),
              child: const Padding(
                padding: EdgeInsets.only(left: 6, right: 2),
                child: Icon(Iconsax.close_circle_copy, color: VSPColors.error, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}
