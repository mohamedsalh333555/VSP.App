import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';

class SixthTeamFeeDialog extends StatelessWidget {
  final VoidCallback onProceedToPay;
  final VoidCallback onCancel;

  const SixthTeamFeeDialog({
    super.key,
    required this.onProceedToPay,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      backgroundColor: VSPColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
      insetPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(VSPSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebratory Icon
            Container(
              padding: const EdgeInsets.all(VSPSpacing.lg),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: VSPColors.accent, width: 2),
              ),
              child: const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 48),
            ),
            const SizedBox(height: VSPSpacing.lg),

            // Title
            Text(
              isArabic ? ' مواجهة كبرى فوق العادة!' : ' Grand Matchup Tournament!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VSPSpacing.sm),

            // Description
            Text(
              isArabic
                  ? 'رائع! وصلتم إلى 6 فرق فأكثر بنظام "الفايز مستمر". للانضمام بالشريحة الإضافية (حتى 10 فرق)، يتم تطبيق رسم رمزي 25 ج.م لدعم خوادم المنافسات الحية.'
                  : 'Awesome! You are expanding beyond 5 teams into a full Winner-Stays tournament. A small fee of 25 EGP applies for the next tier of 5 teams.',
              style: const TextStyle(
                color: VSPColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VSPSpacing.xl),

            // Fee badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.card_pos_copy, color: VSPColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'الرسم الإضافي: 25 ج.م فقط' : 'Extra Fee: 25 EGP only',
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: VSPSpacing.xl),

            // Actions
            PrimaryButton(
              text: isArabic ? 'متابعة الدفع والإضافة' : 'Proceed & Pay 25 EGP',
              onPressed: () {
                Navigator.pop(context);
                onProceedToPay();
              },
            ),
            const SizedBox(height: VSPSpacing.sm),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onCancel();
              },
              child: Text(
                isArabic ? 'إلغاء والاحتفاظ بـ 5 فرق' : 'Cancel & Keep 5 Teams',
                style: const TextStyle(color: VSPColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
