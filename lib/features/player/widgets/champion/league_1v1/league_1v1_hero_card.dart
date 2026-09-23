import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

/// كارت الهيدر الرئيسي لبطولة 1vs1 مع إبراز نظام الـ 32 لاعب وعدد الجولات
class League1v1HeroCard extends StatelessWidget {
  final String tourneyName;
  final String? governorate;
  final String status;
  final String? scheduledAt;
  final int registeredCount;
  final int targetCount;
  final int remainingCount;
  final double progress;
  final bool isArabic;

  const League1v1HeroCard({
    super.key,
    required this.tourneyName,
    required this.governorate,
    required this.status,
    required this.scheduledAt,
    required this.registeredCount,
    required this.targetCount,
    required this.remainingCount,
    required this.progress,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTarget = targetCount > 0 ? targetCount : 32;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VSPColors.surface, // #18181B الفحمي
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tourneyName,
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // شارة نظام البطولة
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: VSPColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(VSPRadius.full),
                        border: Border.all(color: VSPColors.divider),
                      ),
                      child: Text(
                        isArabic
                            ? 'بطولة تحديات ($effectiveTarget لاعب) • مباريات من 6 جولات'
                            : '$effectiveTarget Players Challenge • 6 Rounds per Match',
                        style: const TextStyle(
                          color: VSPColors.accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSPColors.surfaceAlt,
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                ),
                child: const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 22),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: VSPColors.divider, height: 1),
          const SizedBox(height: 12),

          // السطر السفلي: نسبة اكتمال المقاعد
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'المقاعد المكتملة:' : 'Confirmed Players:',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
              Text(
                '$registeredCount / $effectiveTarget ${isArabic ? "لاعب" : "Players"}',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(VSPRadius.full),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: VSPColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(VSPColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
