import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Interactive selector allowing players to switch between Mobile Wallets and Debit/Credit Cards.
class PaymentMethodSelector extends StatelessWidget {
  final String selectedMethod;
  final bool isArabic;
  final ValueChanged<String> onMethodChanged;

  const PaymentMethodSelector({
    super.key,
    required this.selectedMethod,
    required this.isArabic,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            isArabic ? 'اختر وسيلة الدفع المناسبة لك:' : 'Select Payment Method:',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(height: 10),
        _buildPaymentMethodCard(
          id: 'wallet',
          title: isArabic ? 'محفظة إلكترونية' : 'Mobile Wallet',
          subtitle: isArabic
              ? 'فودافون كاش، أورنج، اتصالات، وي كاش ومحافظ البنوك'
              : 'Pay with Vodafone Cash, Orange, Etisalat & Bank Wallets',
        ),
        const SizedBox(height: 10),
        _buildPaymentMethodCard(
          id: 'card',
          title: isArabic ? 'بطاقة بنكية / كارت ميزة' : 'Bank Card / Meeza Card',
          subtitle: isArabic
              ? 'دفع آمن بالفيزا أو الماستركارد أو كارت ميزة'
              : 'Secure payment via Debit/Credit card',
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard({
    required String id,
    required String title,
    required String subtitle,
  }) {
    final bool isSelected = selectedMethod == id;

    return InkWell(
      onTap: () => onMethodChanged(id),
      borderRadius: BorderRadius.circular(VSPRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent.withValues(alpha: 0.08) : VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(
            color: isSelected ? VSPColors.accent : VSPColors.divider,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? VSPColors.accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.black, size: 14) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? VSPColors.accent : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
