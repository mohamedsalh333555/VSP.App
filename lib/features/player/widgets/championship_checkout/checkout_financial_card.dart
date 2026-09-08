import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class CheckoutFinancialCard extends StatelessWidget {
  final double entryFee;
  final double serviceFee;
  final double totalCheckoutPrice;

  const CheckoutFinancialCard({
    super.key,
    required this.entryFee,
    required this.serviceFee,
    required this.totalCheckoutPrice,
  });

  void _showFeeTransparencyModal(BuildContext context, bool isArabic) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VSPColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VSPColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isArabic ? 'شفافية رسوم خدمات المنصة' : 'Platform Service Fee Transparency',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isArabic
                    ? 'رسوم خدمات المنصة تغطي تكاليف المعاملات البنكية المشفرة، وتأمين الجوائز، وتنظيم الجداول والقرعة إلكترونياً، والدعم الفني المباشر للبطولات.'
                    : 'The platform service fee covers encrypted payment processing, prize pool escrow, automated bracket generation, and dedicated tournament management support.',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13.5, height: 1.6),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isArabic ? 'فهمت ذلك' : 'Got it', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل الرسوم والاشتراك',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const Divider(color: VSPColors.divider, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('رسوم اشتراك البطولة:', style: TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
              Text('${entryFee.toInt()} ج.م', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    isArabic ? 'رسوم خدمات المنصة:' : 'Platform Service Fee:',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _showFeeTransparencyModal(context, isArabic),
                    child: const Icon(
                      Iconsax.info_circle_copy,
                      size: 14,
                      color: VSPColors.accent,
                    ),
                  ),
                ],
              ),
              Text('${serviceFee.toStringAsFixed(1)} ج.م', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
            ],
          ),
          const Divider(color: VSPColors.divider, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المبلغ الإجمالي المطلـوب:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text(
                '${totalCheckoutPrice.toStringAsFixed(1)} ج.م',
                style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
