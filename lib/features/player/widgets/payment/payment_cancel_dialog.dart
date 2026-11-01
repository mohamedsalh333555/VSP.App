import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Confirmation dialog when user attempts to leave the checkout payment screen.
class PaymentCancelDialog {
  const PaymentCancelDialog._();

  static Future<bool?> show({
    required BuildContext context,
    required bool isChampionship,
    required bool isArabic,
    required Future<void> Function(BuildContext dialogContext) onConfirmCancel,
  }) {
    final dialogTitle = isChampionship
        ? (isArabic ? 'التراجع عن التسجيل في البطولة؟' : 'Cancel Championship Registration?')
        : (isArabic ? 'التراجع عن عملية الحجز؟' : 'Cancel Booking Checkout?');

    final dialogContent = isChampionship
        ? (isArabic
            ? 'إذا لم تكن قد أكملت الدفع، سيتوقف التسجيل عند الرجوع. إذا أرسلت عملية الدفع بالفعل، انتظر تأكيد الخادم قبل بدء تسجيل جديد.'
            : 'If you have not completed payment, registration will stop when you leave. If you already submitted payment, wait for server confirmation before starting a new registration.')
        : (isArabic
            ? 'إذا لم تكن قد أكملت الدفع، فلن يتم تحصيل مبلغ عند الرجوع. إذا أرسلت عملية الدفع بالفعل، انتظر تأكيد الخادم قبل محاولة الدفع مرة أخرى.'
            : 'If you have not completed payment, no charge will be taken when you leave. If you already submitted a payment, wait for server confirmation before trying again.');

    final dialogContinueText = isChampionship
        ? (isArabic ? 'متابعة التسجيل' : 'Continue Registration')
        : (isArabic ? 'متابعة الدفع' : 'Continue Checkout');

    return showDialog<bool>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(dialogTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          dialogContent,
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48), tapTargetSize: MaterialTapTargetSize.padded),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              dialogContinueText,
              style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48), tapTargetSize: MaterialTapTargetSize.padded),
            onPressed: () => onConfirmCancel(ctx),
            child: Text(
              isArabic ? 'الرجوع للخلف' : 'Go Back',
              style: const TextStyle(color: VSPColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
