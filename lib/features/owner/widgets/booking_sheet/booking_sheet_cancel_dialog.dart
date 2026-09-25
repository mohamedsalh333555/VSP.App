import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

enum ManualBookingCancelDecision {
  refund,
  keepAsPenalty,
  abort,
}

/// Confirmation dialog for cancelling an owner pitch booking, with deposit handling.
class BookingSheetCancelDialog {
  const BookingSheetCancelDialog._();

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String content,
    required String cancelBtn,
    required String confirmBtn,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelBtn, style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmBtn, style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Specialized dialog when cancelling a manual booking with a paid deposit.
  static Future<ManualBookingCancelDecision> showManualDepositOptions({
    required BuildContext context,
    required double depositAmount,
    required bool isArabic,
  }) async {
    final result = await showDialog<ManualBookingCancelDecision>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Iconsax.warning_2_copy, color: VSPColors.warning, size: 22),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'إلغاء حجز بعربون' : 'Cancel Deposit Booking',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic
                  ? 'هذا الحجز مسجل به عربون مقبوض بقيمة (${depositAmount.toInt()} ج.م).\nحدد الإجراء لتسوية حساب الدرج والدفتر بدقة:'
                  : 'This booking has a deposit of (${depositAmount.toInt()} EGP).\nChoose how to reconcile this in your ledger:',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            // Option 1: Refund
            InkWell(
              onTap: () => Navigator.pop(ctx, ManualBookingCancelDecision.refund),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.convert_card_copy, color: VSPColors.info, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'تم رد العربون للعميل' : 'Refund Deposit to Client',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isArabic
                                ? 'تسجيل استرداد وخصم ${depositAmount.toInt()} ج.م من الدفتر'
                                : 'Deducts deposit from daily cash ledger',
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Option 2: Keep Penalty
            InkWell(
              onTap: () => Navigator.pop(ctx, ManualBookingCancelDecision.keepAsPenalty),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.shield_tick_copy, color: VSPColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'احتساب العربون كشرط جزائي' : 'Keep Deposit as Penalty',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isArabic
                                ? 'تثبيت المبلغ كإيراد تعويضي لصالحك'
                                : 'Retain deposit as compensation income',
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ManualBookingCancelDecision.abort),
            child: Text(
              isArabic ? 'تراجع وعدم الإلغاء' : 'Keep Booking',
              style: const TextStyle(color: VSPColors.textSecondary),
            ),
          ),
        ],
      ),
    );
    return result ?? ManualBookingCancelDecision.abort;
  }
}
