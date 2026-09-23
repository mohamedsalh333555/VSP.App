import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// كارت موحد لعرض وسائل الدفع الإلكتروني المعتمدة (فيزا، ماستركارد، ميزة، ومحافظ الهاتف)
/// بتصميم نظام VSP (فحمي وأخضر نيون فقط) بدون تكرار أو تشتيت للعميل
class PaymentMethodSelector extends StatelessWidget {
  final String? selectedMethod;
  final bool isArabic;
  final ValueChanged<String>? onMethodChanged;

  const PaymentMethodSelector({
    super.key,
    this.selectedMethod,
    required this.isArabic,
    this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface, // #18181B الفحمي
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(
          color: VSPColors.divider,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── السطر العلوي: العنوان وشارة الأمان ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Iconsax.shield_tick_copy,
                    color: VSPColors.accent, // #9FDF02
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'وسائل الدفع المعتمدة' : 'Accepted Payment Methods',
                    style: const TextStyle(
                      color: VSPColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                  border: Border.all(
                    color: VSPColors.accent.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Iconsax.lock_copy,
                      color: VSPColors.accent,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isArabic ? 'دفع آمن 100%' : '100% Secure',
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── 1. البطاقات البنكية وكروت ميزة ──
          _buildMethodItem(
            icon: Iconsax.card_copy,
            title: isArabic ? 'البطاقات البنكية وكارت ميزة' : 'Bank Cards & Meeza',
            subtitle: isArabic
                ? 'فيزا، ماستركارد، كارت ميزة الوطني'
                : 'Visa, Mastercard & Meeza Debit/Credit Cards',
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: VSPColors.divider, height: 1, thickness: 1),
          ),

          // ── 2. المحافظ الإلكترونية الذكية ──
          _buildMethodItem(
            icon: Iconsax.mobile_copy,
            title: isArabic ? 'المحافظ الذكية الإلكترونية' : 'Smart Mobile Wallets',
            subtitle: isArabic
                ? 'فودافون كاش، أورنج، اتصالات، وي كاش، ومحافظ البنوك'
                : 'Vodafone Cash, Orange, Etisalat, WE & Bank Wallets',
          ),

          const SizedBox(height: 12),

          // ── ملاحظة إرشادية هادئة ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.sm),
            ),
            child: Row(
              children: [
                const Icon(
                  Iconsax.info_circle_copy,
                  color: VSPColors.textSecondary,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'ستختار وسيلة الدفع المناسبة لك مباشرة داخل بوابة Paymob الرسمية.'
                        : 'You will choose your preferred payment method on the official Paymob gateway.',
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: VSPColors.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(
              color: VSPColors.divider,
              width: 0.8,
            ),
          ),
          child: Icon(
            icon,
            color: VSPColors.accent, // #9FDF02
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
