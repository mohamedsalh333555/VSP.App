import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Fallback view for Web or browsers opening Paymob in external window.
class PaymobWebFallbackView extends StatelessWidget {
  final VoidCallback onReopen;
  final VoidCallback onManualVerify;

  const PaymobWebFallbackView({
    super.key,
    required this.onReopen,
    required this.onManualVerify,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VSPSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.card_pos_copy, size: 64, color: VSPColors.accent),
            const SizedBox(height: VSPSpacing.lg),
            Text(
              isArabic ? 'جاري فتح بوابة الدفع الآمنة...' : 'Opening secure payment gateway...',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VSPSpacing.md),
            Text(
              isArabic
                  ? 'يرجى إتمام عملية الدفع في النافذة الجديدة، ثم العودة للتطبيق.'
                  : 'Please complete the payment in the new browser tab, then return here.',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VSPSpacing.xl),
            ElevatedButton.icon(
              onPressed: onReopen,
              icon: const Icon(Iconsax.export_3_copy, size: 18),
              label: Text(isArabic ? 'إعادة فتح نافذة الدفع' : 'Re-open Payment Window'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onManualVerify,
              icon: const Icon(Iconsax.refresh_copy, size: 16, color: VSPColors.accent),
              label: Text(
                isArabic ? 'التحقق من الدفع يدويًا' : 'Verify Payment Status',
                style: const TextStyle(color: VSPColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
