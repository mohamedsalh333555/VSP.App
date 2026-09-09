import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Modal dialog helpers for Owner Tournament Dashboard.
class TournamentDashboardDialogs {
  const TournamentDashboardDialogs._();

  /// Prompts owner about unpaid teams before generating draw or starting.
  static Future<bool?> showUnpaidTeamsWarning(
    BuildContext context, {
    required String unpaidNames,
    required double entryFee,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(l10n.warning, style: const TextStyle(color: VSPColors.warning, fontWeight: FontWeight.bold)),
        content: Text(
          l10n.unpaidTeamsWarning(unpaidNames),
          style: const TextStyle(color: VSPColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: l10n.cancel,
                  height: 44,
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: PrimaryButton(
                  text: entryFee > 0
                      ? (isAr ? 'فهمت ذلك' : 'Understood')
                      : l10n.proceedAnyway,
                  height: 44,
                  color: VSPColors.warning,
                  textColor: Colors.black,
                  onPressed: () => Navigator.pop(ctx, entryFee <= 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Prompts owner for confirmation if starting with fewer than max registered teams.
  static Future<bool?> showForceStartConfirmation(
    BuildContext context, {
    required int teamCount,
    required int maxTeams,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(l10n.forceStartTournament, style: Theme.of(ctx).textTheme.titleLarge),
        content: Text(
          l10n.forceStartWarning(teamCount, maxTeams),
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: l10n.cancel,
                  height: 44,
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: PrimaryButton(
                  text: l10n.forceStart,
                  height: 44,
                  color: VSPColors.warning,
                  textColor: Colors.black,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
