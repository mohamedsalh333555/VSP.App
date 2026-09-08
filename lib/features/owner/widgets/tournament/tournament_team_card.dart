import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';

/// Card representing a joined team in the tournament dashboard.
class TournamentTeamCard extends StatelessWidget {
  final Team team;
  final bool isPaid;
  final VoidCallback onTogglePayment;
  final VoidCallback onDelete;

  const TournamentTeamCard({
    super.key,
    required this.team,
    required this.isPaid,
    required this.onTogglePayment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: VSPColors.surfaceAlt,
            child: ClipOval(
              child: team.captainImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: team.captainImageUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Icon(Iconsax.people_copy, color: VSPColors.textSecondary, size: 20),
                    )
                  : const Icon(Iconsax.people_copy, color: VSPColors.textSecondary, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  team.captainName,
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: onTogglePayment,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isPaid
                    ? VSPColors.success.withValues(alpha: 0.15)
                    : VSPColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(VSPRadius.full),
                border: Border.all(
                  color: isPaid
                      ? VSPColors.success.withValues(alpha: 0.5)
                      : VSPColors.warning.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPaid ? Iconsax.tick_circle_copy : Iconsax.clock_copy,
                    size: 14,
                    color: isPaid ? VSPColors.success : VSPColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPaid ? (isArabic ? 'تم الدفع' : 'Paid') : (isArabic ? 'معلق' : 'Pending'),
                    style: TextStyle(
                      color: isPaid ? VSPColors.success : VSPColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          IconButton(
            icon: const Icon(Iconsax.trash_copy, color: VSPColors.error, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Confirmation dialog to safely remove a team from a championship.
Future<void> showDeleteTeamConfirmationDialog(
  BuildContext context, {
  required Team team,
  required Championship championship,
  required ValueChanged<Championship> onTeamRemoved,
}) async {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';

  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: VSPColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
      title: Row(
        children: [
          const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 22),
          const SizedBox(width: 8),
          Text(
            isArabic ? 'إلغاء انضمام الفريق؟' : 'Remove Team?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      content: Text(
        isArabic
            ? 'هل أنت متأكد من إلغاء انضمام فريق "${team.name}" من هذه البطولة؟'
            : 'Are you sure you want to remove team "${team.name}" from this tournament?',
        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            isArabic ? 'إلغاء' : 'Cancel',
            style: const TextStyle(color: VSPColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: VSPColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
          ),
          child: Text(
            isArabic ? 'تأكيد الحذف' : 'Confirm Remove',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  if (confirm == true && context.mounted) {
    try {
      final success =
          await TournamentRepository().removeTournamentTeam(championship.id, team.id);
      if (success && context.mounted) {
        final updatedList = List<String>.from(championship.joinedTeams)..remove(team.id);
        final updatedPaid = List<String>.from(championship.paidTeams)..remove(team.id);
        final updated = championship.copyWith(
          joinedTeams: updatedList,
          paidTeams: updatedPaid,
        );
        onTeamRemoved(updated);
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم إلغاء انضمام الفريق بنجاح.' : 'Team removed successfully.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        VSPFeedback.showError(context, e.toString().replaceAll('Exception:', ''));
      }
    }
  }
}
