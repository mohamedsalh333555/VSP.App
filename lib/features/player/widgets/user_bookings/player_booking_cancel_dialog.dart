import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import 'refund_notice_widget.dart';

class PlayerBookingCancelDialog {
  const PlayerBookingCancelDialog._();

  static Future<void> show(BuildContext context, Booking booking) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // The cancellation RPC/Paymob worker calculates the actual refundable
    // amount from completed transactions. Do not guess it from total_price.
    final paymentMethod = booking.paymentMethod;
    final paymentStatus = booking.paymentStatus.toLowerCase();
    final hasPaidAmount = booking.isPaid ||
        booking.isDepositPaid ||
        booking.depositPaid > 0 ||
        ['paid', 'refund_pending', 'refunded'].contains(paymentStatus);
    final isPureCash = paymentMethod.toLowerCase() == 'cash' && !hasPaidAmount;
    final amountConfirmed = booking.refundAmount != null || !hasPaidAmount;
    final actualRefundAmount = booking.refundAmount ?? 0.0;

    // 3. تحديد قناة الاسترداد والمدة المتوقعة
    //    لو كاش صافي — قناة الاسترداد لا تُعرض (مبلغها صفر)
    final refundChannel = switch (paymentMethod.toLowerCase()) {
      'wallet' || 'vodafone_cash' || 'instapay' => RefundChannel.wallet,
      'card' || 'paymob' || 'online'            => RefundChannel.card,
      _                                          => RefundChannel.cash,
    };

    final refundInfo = RefundInfo(
      channel: refundChannel,
      eta: refundChannel == RefundChannel.card
          ? RefundEta.businessDays
          : (refundChannel == RefundChannel.wallet ? RefundEta.minutes : RefundEta.immediate),
      refundAmount: actualRefundAmount,
      amountConfirmed: amountConfirmed,
      hasNoPaidAmount: !hasPaidAmount,
      isPureCashNoDeposit: isPureCash,
    );

    final amountFormatted = !hasPaidAmount
        ? (isArabic ? 'لا يوجد مبلغ مدفوع' : 'No amount paid')
        : (amountConfirmed
            ? '${refundInfo.refundAmount.toStringAsFixed(0)} ${isArabic ? 'جنيه' : l10n.egCurrency}'
            : (isArabic ? 'سيتم التأكيد بعد الإلغاء' : 'Confirmed after cancellation'));

    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        scrollable: true,
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.xl)),
        title: Text(l10n.cancelBooking,
            style: Theme.of(dialogCtx).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.cancelBookingConfirm,
                style: Theme.of(dialogCtx).textTheme.bodyMedium),
            const SizedBox(height: VSPSpacing.md),
            RefundNoticeWidget(
              refundInfo: refundInfo,
              amountFormatted: amountFormatted,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(
            horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          _CancelDialogActions(
            context: context,
            dialogCtx: dialogCtx,
            booking: booking,
            refundInfo: refundInfo,
            l10n: l10n,
            isArabic: isArabic,
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
  final RefundInfo refundInfo;
  final AppLocalizations l10n;
  final bool isArabic;

  const _CancelDialogActions({
    required this.context,
    required this.dialogCtx,
    required this.booking,
    required this.refundInfo,
    required this.l10n,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext _) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keepButton = PrimaryButton(
          text: l10n.keepBooking,
          height: 48,
          color: VSPColors.surfaceAlt,
          textColor: VSPColors.textPrimary,
          onPressed: () => Navigator.pop(dialogCtx),
        );
        final cancelButton = PrimaryButton(
          text: l10n.cancel,
          height: 48,
          color: VSPColors.error,
          textColor: VSPColors.background,
          onPressed: _performCancellation,
        );

        // Stack actions on narrow screens so Arabic labels and touch targets
        // remain readable without compressing two buttons into one short row.
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              keepButton,
              const SizedBox(height: VSPSpacing.sm),
              cancelButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: keepButton),
            const SizedBox(width: VSPSpacing.md),
            Expanded(child: cancelButton),
          ],
        );
      },
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
      final successMsg = isArabic
          ? refundInfo.refundSuccessText()
          : refundInfo.localizedSuccessText(l10n);
      messenger.showSnackBar(SnackBar(
        content: Text(successMsg),
        backgroundColor: VSPColors.accent,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(provider.errorMessage ?? l10n.cancelFailed),
        backgroundColor: VSPColors.error,
      ));
    }
  }
}
