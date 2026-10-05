import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';

/// Owner home finance panel.
///
/// Free users see the essential collected/cash/online numbers and the
/// withdrawable balance. Pro users additionally get collection intelligence:
/// cash still due at the pitch, online payments still pending, and online
/// money collected but not yet eligible for withdrawal.
class OwnerOperationalFinanceCard extends StatelessWidget {
  final double collectedCash;
  final double collectedOnline;
  final double cashDue;
  final double onlinePending;
  final double onlineHeld;
  final double availableBalance;
  final double upcomingValue;
  final bool isProOwner;
  final VoidCallback onOpenLedger;
  final VoidCallback onRequestPayout;
  final VoidCallback? onOpenPayoutHistory;
  final VoidCallback? onUpgrade;
  final bool isArabic;

  const OwnerOperationalFinanceCard({
    super.key,
    required this.collectedCash,
    required this.collectedOnline,
    this.cashDue = 0.0,
    this.onlinePending = 0.0,
    this.onlineHeld = 0.0,
    required this.availableBalance,
    this.upcomingValue = 0.0,
    required this.isProOwner,
    required this.onOpenLedger,
    required this.onRequestPayout,
    this.onOpenPayoutHistory,
    this.onUpgrade,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final currency = isArabic ? 'ج.م' : 'EGP';
    final collectedTotal = collectedCash + collectedOnline;
    final hasBalance = availableBalance > 0.009;
    final dueTotal = cashDue + onlinePending;
    final hasDueMoney = dueTotal > 0.009;

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
                  isArabic ? 'المتحصل اليوم' : 'Collected today',
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
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
                        fontSize: 12,
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
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                collectedTotal.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: VSPColors.accent,
                  letterSpacing: -1.2,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                currency,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: VSPColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MoneySplit(
                  icon: Iconsax.money_3_copy,
                  label: isArabic ? 'كاش متحصل' : 'Cash collected',
                  value: collectedCash,
                  currency: currency,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoneySplit(
                  icon: Iconsax.card_copy,
                  label: isArabic ? 'أونلاين متحصل' : 'Online collected',
                  value: collectedOnline,
                  currency: currency,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isProOwner)
            _buildProCollectionIntelligence(
              currency: currency,
              cashDue: cashDue,
              onlinePending: onlinePending,
              onlineHeld: onlineHeld,
              dueTotal: dueTotal,
              hasDueMoney: hasDueMoney,
            )
          else
            _buildFreeUpgradePreview(
              hasDueMoney: hasDueMoney,
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.divider),
            ),
            child: Row(
              children: [
                const Icon(
                  Iconsax.wallet_3_copy,
                  size: 18,
                  color: VSPColors.accent,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'جاهز للسحب الآن' : 'Available for withdrawal',
                        style: const TextStyle(
                          color: VSPColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${availableBalance.toStringAsFixed(0)} $currency',
                        style: const TextStyle(
                          color: VSPColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
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
                            : 'No balance is currently available for withdrawal',
                      );
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasBalance
                          ? VSPColors.accent
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                    child: Text(
                      isArabic ? 'سحب' : 'Withdraw',
                      style: TextStyle(
                        color: hasBalance ? Colors.black : VSPColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onOpenPayoutHistory != null) ...[
            const SizedBox(height: 9),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onOpenPayoutHistory!();
              },
              behavior: HitTestBehavior.opaque,
              child: Text(
                isArabic ? 'عرض سجل السحوبات' : 'View withdrawal history',
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (upcomingValue > 0.009) ...[
            const SizedBox(height: 10),
            Text(
              isArabic
                  ? 'الحجوزات القادمة المؤكدة: ${upcomingValue.toStringAsFixed(0)} $currency'
                  : 'Upcoming confirmed bookings: ${upcomingValue.toStringAsFixed(0)} $currency',
              style: const TextStyle(
                color: VSPColors.textSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProCollectionIntelligence({
    required String currency,
    required double cashDue,
    required double onlinePending,
    required double onlineHeld,
    required double dueTotal,
    required bool hasDueMoney,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSPColors.inputFill,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: hasDueMoney
              ? VSPColors.warning.withValues(alpha: 0.45)
              : VSPColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Iconsax.money_remove_copy,
                size: 17,
                color: VSPColors.warning,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  isArabic ? 'فلوس لسه ما اتحصلتش' : 'Money still to collect',
                  style: const TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${dueTotal.toStringAsFixed(0)} $currency',
                style: TextStyle(
                  color: hasDueMoney ? VSPColors.warning : VSPColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MoneySplit(
                  icon: Iconsax.money_3_copy,
                  label: isArabic ? 'كاش مستحق' : 'Cash due',
                  value: cashDue,
                  currency: currency,
                  highlight: cashDue > 0.009,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MoneySplit(
                  icon: Iconsax.card_copy,
                  label: isArabic ? 'أونلاين معلق' : 'Online pending',
                  value: onlinePending,
                  currency: currency,
                  highlight: onlinePending > 0.009,
                ),
              ),
            ],
          ),
          if (onlineHeld > 0.009) ...[
            const SizedBox(height: 9),
            Text(
              isArabic
                  ? 'أونلاين متحصل لكن غير متاح للسحب بعد: ${onlineHeld.toStringAsFixed(0)} $currency'
                  : 'Online collected but not withdrawable yet: ${onlineHeld.toStringAsFixed(0)} $currency',
              style: const TextStyle(
                color: VSPColors.textSecondary,
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFreeUpgradePreview({
    required bool hasDueMoney,
  }) {
    final previewValue = isArabic ? 'متاح مع Pro' : 'Available with Pro';

    return GestureDetector(
      onTap: onUpgrade,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VSPColors.proAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: VSPColors.proAccent.withValues(alpha: 0.32),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Iconsax.money_remove_copy,
                  size: 17,
                  color: VSPColors.proAccent,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'تفاصيل الفلوس اللي لسه ما اتحصلتش'
                        : 'Uncollected money details',
                    style: const TextStyle(
                      color: VSPColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Text(
                  'Pro',
                  style: TextStyle(
                    color: VSPColors.proAccent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _LockedMoneyPreview(
                    icon: Iconsax.money_3_copy,
                    label: isArabic ? 'كاش مستحق' : 'Cash due',
                    value: previewValue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LockedMoneyPreview(
                    icon: Iconsax.card_copy,
                    label: isArabic ? 'أونلاين غير محصل' : 'Online not collected',
                    value: previewValue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              hasDueMoney
                  ? (isArabic
                      ? 'فيه فلوس محتاجة متابعة. اشترك في Pro عشان تشوف القيمة والتفاصيل والإجراء المطلوب.'
                      : 'Money needs attention. Subscribe to Pro to see the amounts, details, and required action.')
                  : (isArabic
                      ? 'مع Pro هتعرف الفلوس المستحقة عليك/لك فوراً بدل ما تكتشفها متأخر.'
                      : 'With Pro, you can see collection gaps immediately instead of discovering them late.'),
              style: const TextStyle(
                color: VSPColors.textSecondary,
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }}



class _LockedMoneyPreview extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LockedMoneyPreview({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: VSPColors.textMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VSPColors.proAccent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneySplit extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String currency;
  final bool highlight;

  const _MoneySplit({
    required this.icon,
    required this.label,
    required this.value,
    required this.currency,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: highlight
              ? VSPColors.warning.withValues(alpha: 0.40)
              : VSPColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: highlight
                    ? VSPColors.warning
                    : VSPColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(0)} $currency',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
