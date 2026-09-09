import 'package:flutter/material.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../../shared/widgets/primary_button.dart';

/// Bottom action bar for the tournament creation and edit wizard.
class TournamentWizardBottomBar extends StatelessWidget {
  final int currentStep;
  final bool isLoading;
  final bool isEditing;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const TournamentWizardBottomBar({
    super.key,
    required this.currentStep,
    required this.isLoading,
    required this.isEditing,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.fromLTRB(
        VSPSpacing.md,
        VSPSpacing.md,
        VSPSpacing.md,
        MediaQuery.of(context).padding.bottom + VSPSpacing.md,
      ),
      color: VSPColors.background,
      child: Row(
        children: [
          if (currentStep > 0) ...[
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: onPrev,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VSPColors.textSecondary,
                    side: const BorderSide(color: VSPColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                  ),
                  child: Text(l10n.backButton),
                ),
              ),
            ),
            const SizedBox(width: VSPSpacing.md),
          ],
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 56,
              child: PrimaryButton(
                text: currentStep == 2
                    ? (isEditing
                        ? l10n.updateChanges
                        : l10n.createTournamentTitle)
                    : l10n.nextButton,
                isLoading: isLoading,
                onPressed: isLoading ? () {} : onNext,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
