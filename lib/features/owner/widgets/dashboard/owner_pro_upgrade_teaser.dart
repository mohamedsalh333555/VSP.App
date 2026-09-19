import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// بطاقة الترقية الذكية للباقة الأساسية
class OwnerProUpgradeTeaser extends StatelessWidget {
  final VoidCallback onUpgrade;
  final bool isArabic;
  final bool isVerified;

  const OwnerProUpgradeTeaser({
    super.key,
    required this.onUpgrade,
    required this.isArabic,
    this.isVerified = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: VSPColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                ),
                child: const Icon(Iconsax.crown_copy, color: VSPColors.warning, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isArabic ? 'ضاعف أرباحك مع الباقة الاحترافية (PRO)' : 'Maximize Growth with PRO Plan',
                  style: const TextStyle(color: VSPColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isArabic
                ? 'أدر حتى 3 ملاعب كاملة، واحصل على مركز التحليلات العميقة، وتقارير نسبة الإشغال، ورسوم بيانية لأفضل أيام الأسبوع وساعات الذروة.'
                : 'Operate up to 3 pitches, get Deep Insights Center, Occupancy rate analytics, and weekly revenue & peak hour charts.',
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35)),
              ),
              child: Center(
                child: Text(
                  isArabic ? 'ترقية الآن (1000 ج.م / شهر)' : 'Upgrade to PRO (1000 EGP / mo)',
                  style: const TextStyle(
                    color: VSPColors.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
