import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';

/// لوحة ملخص الحسابات المالية (تنبيه تقييد الكاش للمتخلفين عن الحضور، وتفاصيل العربون والمتبقي بالملعب)
class BookingFinancialSummary extends StatelessWidget {
  final Stadium stadium;
  final double totalPrice;

  const BookingFinancialSummary({
    super.key,
    required this.stadium,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context)!;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isCashLocked = (authProvider.userModel?.noShowCount ?? 0) >= 2;
    final deposit = stadium.depositAmount;

    if (isCashLocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.card_pos_copy, color: VSPColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? "الدفع الإلكتروني المقترح" : "Smart Online Payment",
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isArabic
                      ? "الحجز النقدي مقيد مؤقتاً - يرجى الدفع أونلاين بالفيزا أو المحفظة لتأكيد مكانك فوراً واستعادة تقييمك."
                      : "Cash booking is temporarily restricted - Pay online via card or mobile wallet to confirm your spot immediately and restore your rating.",
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
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
                  isArabic ? 'عربون الحجز المطلوبة' : 'Upfront Deposit Required',
                  style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${deposit.toInt()} ${l10n.egCurrency}',
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
                  '${(totalPrice - deposit).clamp(0, double.infinity).toInt()} ${l10n.egCurrency}',
                  style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
