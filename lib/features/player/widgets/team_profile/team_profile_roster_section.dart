import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class TeamProfileRosterSection extends StatelessWidget {
  final List<UserModel> members;
  final bool isLoading;

  const TeamProfileRosterSection({
    super.key,
    required this.members,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isArabic ? 'قائمة اللاعبين' : 'Team Roster', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: VSPSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(VSPSpacing.md),
          decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg)),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                  ),
                )
              : members.isEmpty
                  ? Center(
                      child: Text(
                        isArabic ? 'لا يوجد أعضاء مضافين حالياً' : 'No team members added yet',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: members.map((member) => _buildMemberChip(member)).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildMemberChip(UserModel user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: VSPColors.surface,
            backgroundImage: (user.profileImageUrl?.isNotEmpty ?? false)
                ? NetworkImage(user.profileImageUrl!)
                : null,
            child: (user.profileImageUrl?.isEmpty ?? true)
                ? const Icon(Iconsax.user_copy, color: VSPColors.textSecondary, size: 10)
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            user.name ?? 'Player',
            style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
