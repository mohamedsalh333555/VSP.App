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

  /// Prompts owner for confirmation when cancelling a tournament (with refund warning).
  static Future<bool?> showCancelTournamentConfirmation(
    BuildContext context, {
    required String tournamentName,
    required int teamsCount,
    required int paidTeamsCount,
    required bool isTeamLeague,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: VSPColors.warning),
            const SizedBox(width: 8),
            Text(
              isAr ? 'إلغاء البطولة' : 'Cancel Tournament',
              style: const TextStyle(color: VSPColors.warning, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr
                  ? 'هل أنت متأكد من رغبتك في إلغاء بطولة "$tournamentName"؟'
                  : 'Are you sure you want to cancel "$tournamentName"?',
              style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (paidTeamsCount > 0)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VSPColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.warning.withValues(alpha: 0.4)),
                ),
                child: Text(
                  isAr
                      ? 'تنبيه مالي: يوجد $paidTeamsCount فرق مسددة للرسوم، وسيتم تحويل المبالغ لحالة الاسترداد المالي (Refund) تلقائياً.'
                      : 'Financial Notice: $paidTeamsCount teams paid the entry fee. Funds will be queued for automatic refund.',
                  style: const TextStyle(color: VSPColors.warning, fontSize: 13),
                ),
              )
            else if (teamsCount > 0)
              Text(
                isAr
                    ? 'يوجد $teamsCount فرق منضمة وسيتم إشعارهم بإلغاء البطولة.'
                    : '$teamsCount registered teams will be notified of cancellation.',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'لا يمكن التراجع عن إلغاء البطولة بمجرد تأكيد الإجراء.'
                  : 'This action cannot be undone once confirmed.',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
          ],
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
                  text: isAr ? 'تأكيد الإلغاء' : 'Confirm Cancel',
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

  /// Prompts owner for permanent deletion (only permitted when no teams joined).
  static Future<bool?> showDeleteTournamentConfirmation(
    BuildContext context, {
    required String tournamentName,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: VSPColors.error),
            const SizedBox(width: 8),
            Text(
              isAr ? 'حذف البطولة نهائياً' : 'Delete Tournament',
              style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr
                  ? 'هل أنت متأكد من حذف بطولة "$tournamentName" نهائياً؟'
                  : 'Are you sure you want to permanently delete "$tournamentName"?',
              style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'سيتم مسح بيانات البطولة بالكامل من النظام ولن يمكن استرجاعها.'
                  : 'All championship data will be permanently wiped and cannot be recovered.',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
            ),
          ],
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
                  text: isAr ? 'حذف نهائي' : 'Delete',
                  height: 44,
                  color: VSPColors.error,
                  textColor: Colors.white,
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

