import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_money_formatter.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';

/// لوحة ملخص الحسابات المالية (تنبيه تقييد الكاش للمتخلفين عن الحضور، وتفاصيل العربون والمتبقي بالملعب)
class BookingFinancialSummary extends StatelessWidget {
  final Stadium stadium;
  final double totalPrice;
  final bool hasSelectedSlots;
  final bool isOpenJoin;

  const BookingFinancialSummary({
    super.key,
    required this.stadium,
    required this.totalPrice,
    required this.hasSelectedSlots,
    this.isOpenJoin = false,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context)!;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isCashLocked = (authProvider.userModel?.noShowCount ?? 0) >= 2;
    final deposit = stadium.depositAmount;

    // Collective bookings require full online payment, not a venue cash promise.
    if (isOpenJoin) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Text(
          isArabic
              ? 'الحجز التجميعي يتطلب سداد القيمة كاملة أونلاين بعد التحقق من بيانات الحجز.'
              : 'Collective bookings require full online payment after the booking details are verified.',
          style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, height: 1.4),
        ),
      );
    }
    if (isCashLocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.card_pos_copy, color: VSPColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? "الدفع الإلكتروني المطلوب" : "Online Payment Required",
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isArabic
                      ? "الحجز النقدي مقيد وفق سجل الحضور. أكمل الدفع الإلكتروني بعد التحقق من شروط الحجز."
                      : "Cash booking is restricted based on attendance history. Use electronic payment after booking eligibility is verified.",
                  style: const TextStyle(color: VSPColors.white, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: VSPSpacing.md),
        ],
      );
    }

    if (deposit > 0 && stadium.needsDeposit) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic ? 'عربون الحجز المطلوب' : 'Upfront Deposit Required',
                  style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${VSPMoneyFormatter.amount(deposit)} ${l10n.egCurrency}',
                  style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic ? 'المتبقي عند الملعب' : 'Remaining at Pitch',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
                Text(
                  !hasSelectedSlots
                      ? (isArabic ? 'يُحسب بعد اختيار الموعد' : 'Calculated after selecting a slot')
                      : (!totalPrice.isFinite || !deposit.isFinite || deposit > totalPrice)
                          ? (isArabic ? 'راجع السعر والعربون' : 'Review price and deposit')
                          : '${VSPMoneyFormatter.amount(totalPrice - deposit)} ${l10n.egCurrency}',
                  style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.money_tick_copy, color: VSPColors.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic
                  ? 'وسيلة الدفع هتتحدد بعد التحقق من الموقع وشروط الحجز. المبلغ النهائي بيتأكد قبل الدفع.'
                  : 'Payment methods depend on location and booking rules. The final amount is verified before payment.',
              style: const TextStyle(
                color: VSPColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
