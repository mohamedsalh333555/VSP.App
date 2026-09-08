import 'package:flutter/material.dart';
import '../../../../core/repositories/team_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import 'team_management_service.dart';

/// Presentation dialogs for team membership lifecycle actions (leave & delete).
class TeamDialogs {
  const TeamDialogs._();

  /// Displays confirmation dialog for leaving a team.
  static void showLeaveConfirmation(
    BuildContext context, {
    required Team team,
    required String userId,
    required bool isCaptain,
    required VoidCallback onSavingStarted,
    required VoidCallback onSavingFinished,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final String contentText = isCaptain
        ? (isArabic
            ? 'أنت كابتن الفريق. عند مغادرتك، سيتم نقل شارة الكابتنة وقيادة الفريق تلقائياً إلى العضو التالي. هل أنت متأكد؟'
            : 'You are the captain. Leaving will automatically transfer captaincy to the next member. Are you sure?')
        : (isArabic
            ? 'هل أنت متأكد من رغبتك في مغادرة هذا الفريق؟'
            : 'Are you sure you want to leave this team?');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(
          isCaptain
              ? (isArabic ? 'مغادرة وتسليم الكابتنة' : 'Leave & Transfer Captaincy')
              : (isArabic ? 'مغادرة الفريق' : 'Leave Team'),
          style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          contentText,
          style: const TextStyle(color: VSPColors.textSecondary, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: isArabic ? 'إلغاء' : 'Cancel',
                  height: 48,
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: PrimaryButton(
                  text: isArabic ? 'تأكيد المغادرة' : 'Confirm Leave',
                  height: 48,
                  color: VSPColors.error,
                  textColor: Colors.white,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    onSavingStarted();
                    try {
                      await TeamRepository().removeMemberFromTeam(team.id, userId, '');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isCaptain
                            ? (isArabic ? 'تمت مغادرة الفريق ونقل شارة الكابتنة بنجاح.' : 'Left team and transferred captaincy.')
                            : (isArabic ? 'تمت مغادرة الفريق بنجاح.' : 'Left team successfully.')),
                        backgroundColor: VSPColors.success,
                      ));
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (e) {
                      if (!context.mounted) return;
                      final displayMsg = TeamManagementService.formatTeamErrorMessage(e, isArabic: isArabic);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(displayMsg), backgroundColor: VSPColors.error),
                      );
                    } finally {
                      onSavingFinished();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Displays confirmation dialog for deleting an entire team.
  static void showDeleteConfirmation(
    BuildContext context, {
    required Team team,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(l10n.deleteTeam, style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(l10n.deleteTeamConfirm, style: const TextStyle(color: VSPColors.textSecondary)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: l10n.cancel,
                  height: 48,
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: PrimaryButton(
                  text: l10n.delete,
                  height: 48,
                  color: VSPColors.error,
                  textColor: VSPColors.background,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      final success = await TeamRepository().deleteTeam(team.id);
                      if (!context.mounted) return;
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.teamDeletedSuccess), backgroundColor: VSPColors.error),
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      final displayMsg = TeamManagementService.formatTeamErrorMessage(e, isArabic: isArabic);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(displayMsg), backgroundColor: VSPColors.error),
                      );
                    }
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
