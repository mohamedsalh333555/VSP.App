import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Renders the 5-minute atomic hold countdown banner and the large checkout amount header card.
class PaymentCountdownHeader extends StatelessWidget {
  final int remainingSeconds;
  final double amountToPay;
  final double? totalAmountWithFees;
  final bool isChampionship;
  final bool hasDeposit;
  final String currency;
  final bool isArabic;

  const PaymentCountdownHeader({
    super.key,
    required this.remainingSeconds,
    required this.amountToPay,
    this.totalAmountWithFees,
    required this.isChampionship,
    required this.hasDeposit,
    required this.currency,
    required this.isArabic,
  });

  static String formatCountdown(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final hasVerifiedTotal = totalAmountWithFees != null;
    final double displayAmount = totalAmountWithFees ?? amountToPay;
    final String formattedAmount = (displayAmount % 1 == 0)
        ? displayAmount.toInt().toString()
        : displayAmount.toStringAsFixed(1);

    return Column(
      children: [
        // 1. Hold Countdown Timer Banner (only for pitch bookings)
        if (!isChampionship) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.timer_1_copy, color: VSPColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'تم تثبيت الوقت لك مؤقتاً لمدة:' : 'Slot temporarily held for:',
                      style: const TextStyle(color: VSPColors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: remainingSeconds <= 60 ? VSPColors.error : VSPColors.accent,
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatCountdown(remainingSeconds),
                        style: VSPTypography.numericStyle.copyWith(
                          color: VSPColors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isArabic ? 'دقيقة' : 'min',
                        style: const TextStyle(
                          color: VSPColors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSPSpacing.lg),
        ],

        // 2. Amount Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(VSPSpacing.lg),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.xl),
            border: Border.all(color: VSPColors.surfaceAlt, width: 1.2),
          ),
          child: Column(
            children: [
              Text(
                hasVerifiedTotal
                    ? (isChampionship
                        ? (isArabic ? 'إجمالي الاشتراك المطلوب الآن' : 'Total Entry Fee Due Now')
                        : (isArabic ? 'المبلغ المطلوب دفعه الآن' : 'Total Amount Due Now'))
                    : (isChampionship
                        ? (isArabic ? 'رسوم الاشتراك الأساسية قبل الرسوم' : 'Base entry fee before fees')
                        : (isArabic ? 'السعر الأساسي قبل الرسوم' : 'Base amount before fees')),
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: VSPSpacing.xs),
              Text(
                '$formattedAmount $currency',
                style: VSPTypography.numericStyle.copyWith(
                  color: VSPColors.accent,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              if (!hasVerifiedTotal) ...[
                const SizedBox(height: VSPSpacing.xs),
                Text(
                  isArabic
                      ? 'الإجمالي النهائي غير متاح حتى يتم التحقق من الرسوم.'
                      : 'Final total is unavailable until fees are verified.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: VSPColors.warning, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
