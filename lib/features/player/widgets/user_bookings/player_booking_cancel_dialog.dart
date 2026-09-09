import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Cancellation confirmation dialog for [PlayerBookingCard].
///
/// Shows a deposit-refund notice when the booking has a paid deposit,
/// then performs the cancellation through [BookingProvider].
class PlayerBookingCancelDialog {
  const PlayerBookingCancelDialog._();

  static Future<void> show(BuildContext context, Booking booking) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final bool hasDeposit = booking.isDepositPaid && booking.depositPaid > 0;

    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
        title: Text(l10n.cancelBooking, style: Theme.of(dialogCtx).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.cancelBookingConfirm, style: Theme.of(dialogCtx).textTheme.bodyMedium),
            if (hasDeposit) ...[
              const SizedBox(height: VSPSpacing.md),
              _DepositRefundNotice(isArabic: isArabic),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(
            horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          _CancelDialogActions(
            context: context,
            dialogCtx: dialogCtx,
            booking: booking,
            l10n: l10n,
          ),
        ],
      ),
    );
  }
}

// ── Private sub-widgets ───────────────────────────────────────────────────────

class _DepositRefundNotice extends StatelessWidget {
  final bool isArabic;
  const _DepositRefundNotice({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.rotate_left_copy, color: VSPColors.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic
                  ? 'سيتم استرداد مبلغ العربون تلقائياً وإرجاعه إلى حسابك البنكي (InstaPay) أو محفظتك الإلكترونية التي دفعت منها خلال دقائق معدودة .'
                  : 'The deposit will be automatically refunded directly to your mobile wallet or bank account linked to InstaPay within minutes .',
              style: const TextStyle(
                color: VSPColors.accent,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelDialogActions extends StatelessWidget {
  final BuildContext context;
  final BuildContext dialogCtx;
  final Booking booking;
  final AppLocalizations l10n;

  const _CancelDialogActions({
    required this.context,
    required this.dialogCtx,
    required this.booking,
    required this.l10n,
  });

  @override
  Widget build(BuildContext _) {
    return Row(
      children: [
        Expanded(
          child: PrimaryButton(
            text: l10n.keepBooking,
            height: 48,
            color: VSPColors.surfaceAlt,
            textColor: VSPColors.textPrimary,
            onPressed: () => Navigator.pop(dialogCtx),
          ),
        ),
        const SizedBox(width: VSPSpacing.md),
        Expanded(
          child: PrimaryButton(
            text: l10n.cancel,
            height: 48,
            color: VSPColors.error,
            textColor: VSPColors.background,
            onPressed: () => _performCancellation(),
          ),
        ),
      ],
    );
  }

  Future<void> _performCancellation() async {
    final provider = Provider.of<BookingProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.cancelling),
      duration: const Duration(seconds: 1),
    ));
    Navigator.pop(dialogCtx);
    final success = await provider.cancelBooking(booking.id);
    if (success) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.cancelSuccess),
        backgroundColor: VSPColors.warning,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(provider.errorMessage ?? l10n.cancelFailed),
        backgroundColor: VSPColors.error,
      ));
    }
  }
}
