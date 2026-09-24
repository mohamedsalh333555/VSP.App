import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Footer section displaying the encryption security guarantee, progress indicator, and payment CTA button.
class PaymentSecurityFooter extends StatelessWidget {
  final bool isLoading;
  final bool isAwaitingWebhook;
  final bool isArabic;
  final bool canProceed;
  final double? totalAmount;
  final VoidCallback onProceed;

  const PaymentSecurityFooter({
    super.key,
    required this.isLoading,
    required this.isAwaitingWebhook,
    required this.isArabic,
    required this.canProceed,
    this.totalAmount,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isLoading || isAwaitingWebhook) ...[
          const SizedBox(height: 10),
          const CircularProgressIndicator(
            color: VSPColors.accent,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'جاري إصدار وتأكيد تذكرة الحجز... ' : 'Issuing your booking ticket... ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic ? 'لحظات وننقلك لتفاصيل الحجز' : 'Redirecting in a moment...',
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
        ] else ...[
          const Icon(Iconsax.lock_copy, color: VSPColors.textSecondary, size: 16),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'جميع المعاملات تشفير آمن 100% ومحمية بواسطة بوابة الدفع المعتمدة.'
                : '100% secure encrypted payment via licensed Payment Gateway.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.4),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: PrimaryButton(
            text: isArabic
                ? (totalAmount != null
                    ? 'الانتقال للدفع الآمن • ${totalAmount!.toStringAsFixed(1)} ج.م'
                    : 'الانتقال للدفع الآمن')
                : (totalAmount != null
                    ? 'Proceed to Checkout • ${totalAmount!.toStringAsFixed(1)} EGP'
                    : 'Proceed to Secure Checkout'),
            isLoading: isLoading || isAwaitingWebhook,
            onPressed: canProceed ? onProceed : null,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
