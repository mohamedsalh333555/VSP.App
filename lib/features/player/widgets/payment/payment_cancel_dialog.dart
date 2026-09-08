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
            ? 'إذا تراجعت الآن، لن يتم استكمال التسجيل في البطولة وسيمكنك العودة في أي وقت.'
            : 'If you go back now, your tournament registration will not be completed.')
        : (isArabic
            ? 'إذا تراجعت الآن، لن يتم خصم أي مبالغ وسيمكنك مراجعة حجزك وتعديله في أي وقت.'
            : 'If you go back now, no charges will be made and you can review your checkout anytime.');

    final dialogContinueText = isChampionship
        ? (isArabic ? 'متابعة التسجيل' : 'Continue Registration')
        : (isArabic ? 'متابعة الدفع' : 'Continue Checkout');

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(dialogTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          dialogContent,
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              dialogContinueText,
              style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
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
