import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// كارت المالية والتشغيل الموحد للباقتين (فحمي وأخضر نيون فقط)
class OwnerOperationalFinanceCard extends StatelessWidget {
  final double availableBalance;
  final double cashThisMonth;
  final double onlineThisMonth;
  final VoidCallback onOpenLedger;
  final VoidCallback onRequestPayout;
  final bool isArabic;

  const OwnerOperationalFinanceCard({
    super.key,
    required this.availableBalance,
    required this.cashThisMonth,
    required this.onlineThisMonth,
    required this.onOpenLedger,
    required this.onRequestPayout,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final currencyLabel = isArabic ? 'ج.م' : 'EGP';
    final hasBalance = availableBalance > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VSPColors.surface, // #18181B الفحمي
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(
          color: VSPColors.divider,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── السطر العلوي: العنوان ورابط كشف الحساب ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'جاهز للسحب الآن' : 'Available for Payout',
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onOpenLedger();
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isArabic ? 'كشف الحساب' : 'Statement',
                      style: const TextStyle(
                        color: VSPColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isArabic ? Icons.arrow_back : Icons.arrow_forward,
                      size: 14,
                      color: VSPColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── السطر الأوسط: الرقم الضخم بالأخضر النيون + زر طلب السحب ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    availableBalance.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: VSPColors.accent, // #9FDF02 الأخضر نيون
                      letterSpacing: -1,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currencyLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: VSPColors.accent,
                    ),
                  ),
                ],
              ),

              // زر سحب الأموال الموحد في نفس المكان لكلا الباقتين
              GestureDetector(
                onTap: hasBalance
                    ? () {
                        HapticFeedback.mediumImpact();
                        onRequestPayout();
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: hasBalance
                        ? VSPColors.accent.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(VSPRadius.full),
                    border: Border.all(
                      color: hasBalance
                          ? VSPColors.accent.withValues(alpha: 0.5)
                          : VSPColors.divider.withValues(alpha: 0.5),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.wallet_3_copy,
                        size: 14,
                        color: hasBalance ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasBalance
                            ? (isArabic ? 'طلب سحب' : 'Payout')
                            : (isArabic ? 'الرصيد 0' : '0 EGP'),
                        style: TextStyle(
                          color: hasBalance ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: VSPColors.divider, height: 1, thickness: 1),
          const SizedBox(height: 14),

          // ── السطر السفلي: كاش هذا الشهر وأونلاين هذا الشهر ──
          Row(
            children: [
              // كاش هذا الشهر
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'كاش هذا الشهر' : 'Cash This Month',
                      style: const TextStyle(
                        color: VSPColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cashThisMonth.toStringAsFixed(0)} $currencyLabel',
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 1,
                height: 28,
                color: VSPColors.divider,
              ),
              const SizedBox(width: 16),

              // أونلاين هذا الشهر
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'أونلاين هذا الشهر' : 'Online This Month',
                      style: const TextStyle(
                        color: VSPColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${onlineThisMonth.toStringAsFixed(0)} $currencyLabel',
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
