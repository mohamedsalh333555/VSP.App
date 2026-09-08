import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// مؤشر خطوات معالج إضافة/تعديل الملعب وشريط التقدم التفاعلي
class AddStadiumStepIndicator extends StatelessWidget {
  final int currentStep;
  final bool isEditing;

  const AddStadiumStepIndicator({
    super.key,
    required this.currentStep,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final labels = [
      isArabic ? 'البيانات' : 'Details',
      isArabic ? 'الخدمات' : 'Features',
      isArabic ? 'الصور' : 'Photos',
    ];

    // Goal Gradient Effect progress calculations
    final int percent = currentStep == 0 ? 33 : (currentStep == 1 ? 66 : 100);
    final String progressText = isEditing
        ? (isArabic ? ' تعديل بيانات وتفاصيل الملعب الحالي' : ' Editing current stadium details')
        : (currentStep == 0
            ? (isArabic ? ' الخطوة 1 من 3: أدخل البيانات الأساسية للملعب' : ' Step 1 of 3: Enter basic details')
            : (currentStep == 1
                ? (isArabic ? ' الخطوة 2 من 3: حدد الميزات والخدمات المتاحة' : ' Step 2 of 3: Select features & options')
                : (isArabic ? ' الخطوة 3 من 3: أضف صور الملعب والمعاينة النهائية' : ' Step 3 of 3: Add photos & preview')));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        children: [
          // Goal Gradient Progress Banner (Only shown when adding a new stadium)
          if (!isEditing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      progressText,
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: VSPColors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$percent%',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Stepper Lines and Circles
          Stack(
            children: [
              // Background Connecting Lines
              Positioned(
                left: 28 / 2 + 12,
                right: 28 / 2 + 12,
                top: 28 / 2 - 1,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: currentStep >= 1 ? VSPColors.accent : VSPColors.divider,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: currentStep >= 2 ? VSPColors.accent : VSPColors.divider,
                      ),
                    ),
                  ],
                ),
              ),
              // Stepper Circles and Text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (i) {
                  final isActive = i <= currentStep;
                  final isCurrent = i == currentStep;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? VSPColors.accent : VSPColors.surface,
                          border: Border.all(
                            color: isActive ? VSPColors.accent : VSPColors.divider,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: i < currentStep
                              ? const Icon(Iconsax.tick_circle_copy, color: Colors.black, size: 16)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: isActive ? Colors.black : VSPColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isCurrent ? VSPColors.accent : VSPColors.textSecondary,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
