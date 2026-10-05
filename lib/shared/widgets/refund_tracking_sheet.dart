import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';
import '../../data/models/refund_info.dart';
import '../../l10n/app_localizations.dart';

enum VSPRefundTrackingState { pending, processing, completed, needsReview }

class VSPRefundTrackingSheet extends StatelessWidget {
  final RefundInfo refundInfo;
  final VSPRefundTrackingState state;
  final String bookingReference;

  const VSPRefundTrackingSheet({super.key, required this.refundInfo, required this.state, required this.bookingReference});

  static Future<void> show(BuildContext context, {required RefundInfo refundInfo, required VSPRefundTrackingState state, required String bookingReference}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: VSPDSColors.transparent,
      builder: (_) => VSPRefundTrackingSheet(refundInfo: refundInfo, state: state, bookingReference: bookingReference),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final title = switch (state) {
      VSPRefundTrackingState.pending => isArabic ? 'تم طلب الاسترداد' : 'Refund requested',
      VSPRefundTrackingState.processing => isArabic ? 'الاسترداد قيد المعالجة' : 'Refund processing',
      VSPRefundTrackingState.completed => isArabic ? 'تم الاسترداد' : 'Refund completed',
      VSPRefundTrackingState.needsReview => isArabic ? 'الاسترداد يحتاج مراجعة' : 'Refund needs review',
    };
    final stateColor = switch (state) {
      VSPRefundTrackingState.completed => VSPDSSemanticColors.success,
      VSPRefundTrackingState.needsReview => VSPDSSemanticColors.error,
      _ => VSPDSSemanticColors.info,
    };
    final channel = switch (refundInfo.channel) {
      RefundChannel.card => isArabic ? 'البطاقة البنكية' : 'Bank card',
      RefundChannel.wallet => isArabic ? 'المحفظة الإلكترونية' : 'Wallet',
      RefundChannel.cash => isArabic ? 'نقدي' : 'Cash',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(VSPDSSpacing.lg, VSPDSSpacing.sm, VSPDSSpacing.lg, VSPDSSpacing.lg),
      decoration: const BoxDecoration(color: VSPDSSemanticColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(VSPDSRadius.bottomSheet))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: VSPDSizes.iconXl, height: VSPDSSpacing.xxs, decoration: BoxDecoration(color: VSPDSSemanticColors.textMuted, borderRadius: BorderRadius.circular(VSPDSRadius.full)))),
          const SizedBox(height: VSPDSSpacing.md),
          Row(children: [
            Container(
              width: VSPDSizes.avatarSm, height: VSPDSizes.avatarSm,
              decoration: BoxDecoration(color: stateColor.withValues(alpha: VSPDSOpacity.selectedSurface), shape: BoxShape.circle, border: Border.all(color: stateColor.withValues(alpha: VSPDSOpacity.border))),
              child: Icon(state == VSPRefundTrackingState.completed ? Iconsax.tick_circle_copy : state == VSPRefundTrackingState.needsReview ? Iconsax.warning_2_copy : Iconsax.refresh_copy, color: stateColor, size: VSPDSizes.iconLg),
            ),
            const SizedBox(width: VSPDSSpacing.sm),
            Expanded(child: Text(title, style: VSPDSTypography.titleLarge.copyWith(fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: VSPDSSpacing.lg),
          _TimelineRow(icon: Iconsax.close_circle_copy, title: isArabic ? 'تم إلغاء الحجز' : 'Booking cancelled', subtitle: isArabic ? 'تم بدء مسار الاسترداد إذا كان هناك مبلغ مدفوع.' : 'The refund flow starts when a paid amount exists.', active: true, color: VSPDSSemanticColors.success),
          _TimelineRow(icon: Iconsax.refresh_copy, title: isArabic ? 'معالجة الاسترداد' : 'Refund processing', subtitle: isArabic ? 'يجري تنفيذ الاسترداد عبر قناة الدفع الأصلية.' : 'The refund is processed through the original payment channel.', active: state != VSPRefundTrackingState.pending, color: VSPDSSemanticColors.info),
          _TimelineRow(icon: Iconsax.tick_circle_copy, title: isArabic ? 'إتمام الاسترداد' : 'Refund completed', subtitle: isArabic ? 'سيظهر المبلغ وفق المدة المتوقعة لطريقة الدفع.' : 'The amount appears according to the expected channel timeline.', active: state == VSPRefundTrackingState.completed, color: VSPDSSemanticColors.success, isLast: true),
          const SizedBox(height: VSPDSSpacing.md),
          Container(
            padding: const EdgeInsets.all(VSPDSSpacing.sm),
            decoration: BoxDecoration(color: VSPDSSemanticColors.surfaceRaised, borderRadius: BorderRadius.circular(VSPDSRadius.md), border: Border.all(color: VSPDSSemanticColors.border)),
            child: Column(children: [
              _DetailRow(label: isArabic ? 'الحجز' : 'Booking', value: '#${bookingReference}'),
              const SizedBox(height: VSPDSSpacing.xs),
              _DetailRow(label: isArabic ? 'المبلغ المسترد' : 'Refund amount', value: '${refundInfo.refundAmount.toStringAsFixed(0)} ${l10n.egCurrency}', valueColor: VSPDSSemanticColors.accent),
              const SizedBox(height: VSPDSSpacing.xs),
              _DetailRow(label: isArabic ? 'القناة' : 'Channel', value: channel),
              const SizedBox(height: VSPDSSpacing.xs),
              _DetailRow(label: isArabic ? 'المدة المتوقعة' : 'Expected time', value: refundInfo.localizedEtaText(l10n)),
              if (refundInfo.hasReference) ...[const SizedBox(height: VSPDSSpacing.xs), _DetailRow(label: isArabic ? 'المرجع' : 'Reference', value: refundInfo.refundTransactionId!)],
              if (refundInfo.refundedAt != null) ...[const SizedBox(height: VSPDSSpacing.xs), _DetailRow(label: isArabic ? 'تاريخ الإتمام' : 'Completed at', value: MaterialLocalizations.of(context).formatMediumDate(refundInfo.refundedAt!.toLocal()))],
            ]),
          ),
          if (state == VSPRefundTrackingState.needsReview) ...[
            const SizedBox(height: VSPDSSpacing.sm),
            Text(isArabic ? 'الاسترداد يحتاج مراجعة يدوية. احتفظ برقم الحجز والمرجع عند التواصل مع الدعم.' : 'This refund needs manual review. Keep the booking and refund references when contacting support.', style: VSPDSTypography.bodyMedium.copyWith(color: VSPDSSemanticColors.error)),
          ],
          const SizedBox(height: VSPDSSpacing.md),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(minimumSize: const Size(0, VSPDSizes.buttonHeight), side: VSPDSBorders.subtle, shape: const StadiumBorder(), foregroundColor: VSPDSSemanticColors.textPrimary, textStyle: VSPDSTypography.compactButton), child: Text(isArabic ? 'إغلاق' : 'Close'))),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final bool active; final Color color; final bool isLast;
  const _TimelineRow({required this.icon, required this.title, required this.subtitle, required this.active, required this.color, this.isLast = false});
  @override
  Widget build(BuildContext context) {
    final tint = active ? color : VSPDSSemanticColors.textMuted;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: VSPDSizes.iconLg, child: Column(children: [
        Icon(icon, size: VSPDSizes.iconMd, color: tint),
        if (!isLast) Container(width: 1, height: VSPDSSpacing.lg, color: VSPDSSemanticColors.border),
      ])),
      const SizedBox(width: VSPDSSpacing.sm),
      Expanded(child: Padding(padding: const EdgeInsets.only(bottom: VSPDSSpacing.sm), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: VSPDSTypography.titleSmall.copyWith(color: active ? VSPDSSemanticColors.textPrimary : VSPDSSemanticColors.textMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: VSPDSSpacing.xxs),
        Text(subtitle, style: VSPDSTypography.bodySmall.copyWith(color: active ? VSPDSSemanticColors.textSecondary : VSPDSSemanticColors.textMuted)),
      ]))),
    ]);
  }
}

class _DetailRow extends StatelessWidget {
  final String label; final String value; final Color? valueColor;
  const _DetailRow({required this.label, required this.value, this.valueColor});
  @override Widget build(BuildContext context) => Row(children: [Expanded(child: Text(label, style: VSPDSTypography.bodySmall)), const SizedBox(width: VSPDSSpacing.sm), Flexible(child: Text(value, textAlign: TextAlign.end, style: VSPDSTypography.labelMedium.copyWith(color: valueColor ?? VSPDSSemanticColors.textPrimary))) ]);
}
