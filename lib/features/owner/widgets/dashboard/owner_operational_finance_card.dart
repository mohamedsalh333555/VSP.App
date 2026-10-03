import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';

class OwnerOperationalFinanceCard extends StatelessWidget {
  final double realizedTotal;
  final double realizedCash;
  final double realizedOnline;
  final double availableBalance;
  final double upcomingValue;
  final VoidCallback onOpenLedger;
  final VoidCallback onRequestPayout;
  final VoidCallback? onOpenPayoutHistory;
  final bool isArabic;

  const OwnerOperationalFinanceCard({
    super.key,
    required this.realizedTotal,
    required this.realizedCash,
    required this.realizedOnline,
    required this.availableBalance,
    this.upcomingValue = 0.0,
    required this.onOpenLedger,
    required this.onRequestPayout,
    this.onOpenPayoutHistory,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final currency = isArabic ? 'ج.م' : 'EGP';
    final hasBalance = availableBalance > 0.009;
    final splitMatchesTotal =
        (realizedTotal - (realizedCash + realizedOnline)).abs() < 0.01;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isArabic ? 'إجمالي المحصل اليوم' : 'Total realized today',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); onOpenLedger(); },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isArabic ? 'كشف الحساب' : 'Statement',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(isArabic ? Icons.arrow_back : Icons.arrow_forward, size: 14, color: VSPColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                realizedTotal.toStringAsFixed(0),
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: VSPColors.accent, letterSpacing: -1.2, height: 1),
              ),
              const SizedBox(width: 6),
              Text(currency, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: VSPColors.accent)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MoneySplit(label: isArabic ? 'كاش' : 'Cash', value: realizedCash, currency: currency)),
              const SizedBox(width: 10),
              Expanded(child: _MoneySplit(label: isArabic ? 'أونلاين مدفوع' : 'Online Paid', value: realizedOnline, currency: currency)),
            ],
          ),
          if (!splitMatchesTotal) ...[
            const SizedBox(height: 8),
            Text(
              isArabic ? 'توجد عملية تحتاج مراجعة محاسبية.' : 'A financial transaction needs reconciliation.',
              style: const TextStyle(color: VSPColors.error, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(color: VSPColors.surfaceAlt, borderRadius: BorderRadius.circular(VSPRadius.md), border: Border.all(color: VSPColors.divider)),
            child: Row(
              children: [
                const Icon(Iconsax.wallet_3_copy, size: 18, color: VSPColors.accent),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isArabic ? 'جاهز للسحب الآن' : 'Available for withdrawal',
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${availableBalance.toStringAsFixed(0)} $currency',
                          style: const TextStyle(color: VSPColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (hasBalance) {
                      onRequestPayout();
                    } else {
                      VSPFeedback.showWarning(context, isArabic ? 'لا يوجد رصيد متاح للسحب حالياً' : 'No balance is currently available for withdrawal');
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasBalance ? VSPColors.accent : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                    child: Text(isArabic ? 'سحب' : 'Withdraw',
                        style: TextStyle(color: hasBalance ? Colors.black : VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
          if (onOpenPayoutHistory != null) ...[
            const SizedBox(height: 9),
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); onOpenPayoutHistory!(); },
              behavior: HitTestBehavior.opaque,
              child: Text(isArabic ? 'عرض سجل السحوبات' : 'View withdrawal history',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ],
          if (upcomingValue > 0.009) ...[
            const SizedBox(height: 10),
            Text(
              isArabic
                  ? 'الحجوزات القادمة المؤكدة: ${upcomingValue.toStringAsFixed(0)} $currency'
                  : 'Upcoming confirmed bookings: ${upcomingValue.toStringAsFixed(0)} $currency',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoneySplit extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  const _MoneySplit({required this.label, required this.value, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: VSPColors.surfaceAlt, borderRadius: BorderRadius.circular(VSPRadius.md), border: Border.all(color: VSPColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text('${value.toStringAsFixed(0)} $currency',
              style: const TextStyle(color: VSPColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
