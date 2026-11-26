import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

/// لوحة ملخص الدفع الإلكتروني الكامل 100% لتأكيد الحجز
class BookingFinancialSummary extends StatelessWidget {
  final Stadium stadium;
  final double totalPrice;

  const BookingFinancialSummary({
    super.key,
    required this.stadium,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.card_pos_copy, color: VSPColors.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic
                  ? 'الدفع الإلكتروني الكامل 100% لتأكيد حجزك فوراً (بالفيزا أو المحفظة)'
                  : '100% Online Payment (Card or Mobile Wallet) to confirm instantly',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
