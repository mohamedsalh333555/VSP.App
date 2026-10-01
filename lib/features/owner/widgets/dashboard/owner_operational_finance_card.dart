import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';

/// كارت المالية والتشغيل الموحد للباقتين (فحمي وأخضر نيون فقط)
class OwnerOperationalFinanceCard extends StatelessWidget {
  final double availableBalance;
  final double cashThisMonth;
  final double onlineThisMonth;
  final double upcomingValue;
  final String timePeriod;
  final String? periodLabel;
  final VoidCallback onOpenLedger;
  final VoidCallback onRequestPayout;
  final bool isArabic;

  const OwnerOperationalFinanceCard({
    super.key,
    required this.availableBalance,
    required this.cashThisMonth,
    required this.onlineThisMonth,
    this.upcomingValue = 0.0,
    this.timePeriod = 'today',
    this.periodLabel,
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
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (hasBalance) {
                    onRequestPayout();
                  } else {
                    VSPFeedback.showWarning(
                      context,
                      isArabic
                          ? 'لا يوجد رصيد متاح للسحب حالياً'
                          : 'No balance available for payout right now',
                    );
                  }
                },
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
                        isArabic ? 'طلب سحب' : 'Payout',
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

          // ── السطر السفلي: كاش محصّل وأونلاين محقق للفترة المحددة ──
          Builder(
            builder: (context) {
              String cashLabel;
              String onlineLabel;
              if (periodLabel != null && periodLabel!.isNotEmpty) {
                cashLabel = isArabic ? 'كاش محصّل ($periodLabel)' : 'Cash Collected ($periodLabel)';
                onlineLabel = isArabic ? 'أونلاين محقق ($periodLabel)' : 'Online Realized ($periodLabel)';
              } else if (timePeriod == 'today') {
                cashLabel = isArabic ? 'كاش محصّل اليوم' : 'Cash Collected Today';
                onlineLabel = isArabic ? 'أونلاين محقق اليوم' : 'Online Realized Today';
              } else if (timePeriod == 'yesterday') {
                cashLabel = isArabic ? 'كاش محصّل أمس' : 'Cash Collected Yesterday';
                onlineLabel = isArabic ? 'أونلاين محقق أمس' : 'Online Realized Yesterday';
              } else if (timePeriod == 'week' || timePeriod == 'thisWeek') {
                cashLabel = isArabic ? 'كاش محصّل هذا الأسبوع' : 'Cash Collected This Week';
                onlineLabel = isArabic ? 'أونلاين محقق هذا الأسبوع' : 'Online Realized This Week';
              } else if (timePeriod == 'month' || timePeriod == 'thisMonth') {
                cashLabel = isArabic ? 'كاش محصّل هذا الشهر' : 'Cash Collected This Month';
                onlineLabel = isArabic ? 'أونلاين محقق هذا الشهر' : 'Online Realized This Month';
              } else if (timePeriod == 'year' || timePeriod == 'thisYear') {
                cashLabel = isArabic ? 'كاش محصّل هذا العام' : 'Cash Collected This Year';
                onlineLabel = isArabic ? 'أونلاين محقق هذا العام' : 'Online Realized This Year';
              } else {
                cashLabel = isArabic ? 'إجمالي الكاش المحصّل' : 'Total Cash Collected';
                onlineLabel = isArabic ? 'إجمالي الأونلاين المحقق' : 'Total Online Realized';
              }

              return Column(
                children: [
                  Row(
                    children: [
                      // كاش محصّل
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cashLabel,
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

                      // أونلاين محقق
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              onlineLabel,
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

                  // عرض قيمة الحجوزات القادمة المؤكدة بشكل منفصل كـ operational metric
                  if (upcomingValue > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(VSPRadius.sm),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Iconsax.calendar_tick_copy,
                                size: 13,
                                color: VSPColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isArabic ? 'قيمة الحجوزات القادمة المؤكدة' : 'Upcoming Confirmed Bookings',
                                style: const TextStyle(
                                  color: VSPColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${upcomingValue.toStringAsFixed(0)} $currencyLabel',
                            style: const TextStyle(
                              color: VSPColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
