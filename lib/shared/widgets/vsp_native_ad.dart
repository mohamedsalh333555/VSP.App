import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

/// Clean internal promotional card widget (no external AdMob/Google Ads dependency).
class VSPNativeAd extends StatelessWidget {
  const VSPNativeAd({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      width: 300,
      height: 240,
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: VSPColors.accent.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(VSPRadius.xs),
                ),
                child: Text(
                  isArabic ? "بطولات VSP" : "VSP Tournaments",
                  style: const TextStyle(
                    color: VSPColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            isArabic ? "بطولات VSP الكبرى 🏆" : "VSP Grand Championships 🏆",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? "نافس الآن مع فريقك في أكبر دوري خماسي واحصل على فرصة للفوز بجوائز قيمة!"
                : "Compete with your team in the biggest 5-a-side league and win cash prizes!",
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Align(
            alignment: isArabic ? Alignment.bottomLeft : Alignment.bottomRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: VSPColors.accent,
                borderRadius: BorderRadius.circular(VSPRadius.md),
              ),
              child: Text(
                isArabic ? "سجل فريقك" : "Register Team",
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
