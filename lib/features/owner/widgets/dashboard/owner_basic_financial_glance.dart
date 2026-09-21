import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/owner_financial_calculator.dart';
import 'owner_time_period_dropdown.dart';

/// كبسولة الأرباح للباقة الأساسية (Basic Financial Glance)
class OwnerBasicFinancialGlance extends StatelessWidget {
  final OwnerFinancialMetrics metrics;
  final String selectedTimePeriod;
  final ValueChanged<String> onTimePeriodChanged;
  final VoidCallback? onSettleDues;
  final bool isArabic;

  const OwnerBasicFinancialGlance({
    super.key,
    required this.metrics,
    required this.selectedTimePeriod,
    required this.onTimePeriodChanged,
    this.onSettleDues,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'الإيرادات' : 'Revenue',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              OwnerTimePeriodDropdown(
                selectedTimePeriod: selectedTimePeriod,
                onChanged: onTimePeriodChanged,
                isArabic: isArabic,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                metrics.totalPipeline.toStringAsFixed(0),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: VSPColors.textPrimary, height: 1),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  isArabic ? 'ج.م إجمالي' : 'EGP Total',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'كاش الملعب' : 'Pitch Cash',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${metrics.pitchCashRevenue.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                        style: const TextStyle(color: VSPColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'رصيد أونلاين' : 'Online Balance',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${metrics.digitalVspBalance.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                        style: const TextStyle(color: VSPColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (onSettleDues != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSettleDues,
                style: OutlinedButton.styleFrom(
                  foregroundColor: VSPColors.accent,
                  side: const BorderSide(color: VSPColors.accent, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Iconsax.wallet_3_copy, size: 18),
                label: Text(
                  isArabic ? 'كشف الحساب وسحب الرصيد' : 'View Ledger & Request Payout',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
