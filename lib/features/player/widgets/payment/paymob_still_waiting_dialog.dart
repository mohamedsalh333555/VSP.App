import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Modal dialog prompting the user when payment verification takes longer than expected.
class PaymobStillWaitingDialog {
  const PaymobStillWaitingDialog._();

  static Future<bool?> show(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Iconsax.timer_1_copy, color: VSPColors.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isArabic ? 'الدفع يستغرق وقتاً أطول من المتوقع ' : 'Payment Taking Longer ',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'عملية التأكيد مع بوابة الدفع تستغرق وقتاً إضافياً. يمكنك مواصلة الانتظار (سنتحقق تلقائياً كل 10 ثوانٍ) أو الإلغاء ورجوع لشاشة الحجز.'
              : 'Payment confirmation is taking longer than expected. You can keep waiting (we will auto-check every 10s) or cancel.',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // Keep waiting
            child: Text(
              isArabic ? 'استمرار الانتظار' : 'Keep Waiting',
              style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), // Cancel & pop
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
            ),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
        ],
      ),
    );
  }
}
