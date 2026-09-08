import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Action buttons for managing team lifecycle: creating, saving changes, deleting, or leaving.
class TeamActionButtons extends StatelessWidget {
  final Team? team;
  final bool isCaptain;
  final bool isSaving;
  final bool hasOtherMembers;
  final VoidCallback onCreateTeam;
  final VoidCallback onUpdateTeam;
  final VoidCallback onDeleteTeam;
  final VoidCallback onLeaveTeam;

  const TeamActionButtons({
    super.key,
    required this.team,
    required this.isCaptain,
    required this.isSaving,
    required this.hasOtherMembers,
    required this.onCreateTeam,
    required this.onUpdateTeam,
    required this.onDeleteTeam,
    required this.onLeaveTeam,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (team == null) {
      return SizedBox(
        width: double.infinity,
        child: PrimaryButton(
          text: l10n.createTeam,
          isLoading: isSaving,
          onPressed: isSaving ? null : onCreateTeam,
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                text: l10n.deleteTeam,
                color: VSPColors.error.withValues(alpha: 0.8),
                textColor: VSPColors.textPrimary,
                onPressed: !isCaptain ? null : onDeleteTeam,
              ),
            ),
            const SizedBox(width: VSPSpacing.md),
            Expanded(
              child: PrimaryButton(
                text: l10n.saveChanges,
                isLoading: isSaving,
                onPressed: (isSaving || !isCaptain) ? null : onUpdateTeam,
              ),
            ),
          ],
        ),
        const SizedBox(height: VSPSpacing.md),
        if (!isCaptain || hasOtherMembers)
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: isCaptain ? "مغادرة الفريق (تسليم الكابتنة)" : "مغادرة الفريق",
              color: VSPColors.error.withValues(alpha: 0.15),
              textColor: VSPColors.error,
              onPressed: onLeaveTeam,
            ),
          ),
      ],
    );
  }
}
