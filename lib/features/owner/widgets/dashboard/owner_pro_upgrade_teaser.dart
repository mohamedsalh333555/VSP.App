import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// بطاقة الترقية الذكية للباقة الأساسية
class OwnerProUpgradeTeaser extends StatelessWidget {
  final VoidCallback onUpgrade;
  final bool isArabic;

  const OwnerProUpgradeTeaser({
    super.key,
    required this.onUpgrade,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            VSPColors.surface,
            VSPColors.accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.crown_copy, color: VSPColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'ضاعف أرباحك مع الباقة الاحترافية (PRO)' : 'Maximize Growth with PRO Plan',
                style: const TextStyle(color: VSPColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'أدر حتى 3 ملاعب كاملة، واحصل على مركز التحليلات العميقة، وتقارير نسبة الإشغال، ورسوم بيانية لأفضل أيام الأسبوع وساعات الذروة.'
                : 'Operate up to 3 pitches, get Deep Insights Center, Occupancy rate analytics, and weekly revenue & peak hour charts.',
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: VSPColors.accent,
                borderRadius: BorderRadius.circular(VSPRadius.full),
              ),
              child: Center(
                child: Text(
                  isArabic ? 'ترقية الآن (1000 ج.م / شهر)' : 'Upgrade to Pro (1000 EGP)',
                  style: const TextStyle(color: Colors.black, fontSize: 12.5, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
