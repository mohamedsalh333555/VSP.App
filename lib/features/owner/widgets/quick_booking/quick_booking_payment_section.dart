import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/custom_text_field.dart';

class QuickBookingPaymentSection extends StatelessWidget {
  final TextEditingController paidAmountController;
  final double totalPrice;
  final double currentPaidAmount;
  final bool isFullyPaid;
  final bool isPartiallyPaid;
  final double remainingBalance;
  final ValueChanged<double> onSelectQuickAmount;

  const QuickBookingPaymentSection({
    super.key,
    required this.paidAmountController,
    required this.totalPrice,
    required this.currentPaidAmount,
    required this.isFullyPaid,
    required this.isPartiallyPaid,
    required this.remainingBalance,
    required this.onSelectQuickAmount,
  });

  Widget _buildQuickAmountChip({
    required String label,
    required double amount,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => onSelectQuickAmount(amount),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(VSPRadius.full),
          border: Border.all(
            color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Payment & Received Amount Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isAr ? 'المبلغ المستلم / المدفوع (ج.م)' : 'Amount Received (EGP)',
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(VSPRadius.full),
              ),
              child: Text(
                '${isAr ? "الإجمالي" : "Total"}: ${totalPrice.toInt()} ${isAr ? "ج.م" : "EGP"}',
                style: const TextStyle(
                  color: VSPColors.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Quick Amount Selection Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildQuickAmountChip(
              label: isAr ? '0 (كاش عند الحضور)' : '0 (Cash on Arrival)',
              amount: 0,
              isSelected: currentPaidAmount == 0,
            ),
            if (totalPrice >= 100)
              _buildQuickAmountChip(
                label: isAr ? '50 ج.م' : '50 EGP',
                amount: 50,
                isSelected: currentPaidAmount == 50,
              ),
            if (totalPrice >= 200)
              _buildQuickAmountChip(
                label: isAr ? '100 ج.م' : '100 EGP',
                amount: 100,
                isSelected: currentPaidAmount == 100,
              ),
            _buildQuickAmountChip(
              label: '${isAr ? "دفع كامل" : "Full"}: ${totalPrice.toInt()} ${isAr ? "ج" : ""}',
              amount: totalPrice,
              isSelected: currentPaidAmount == totalPrice,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Custom Paid Amount Input
        CustomTextField(
          controller: paidAmountController,
          hintText: '0',
          prefixIcon: Iconsax.wallet_check_copy,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),

        // Real-time Status Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isFullyPaid
                ? VSPColors.accent.withValues(alpha: 0.12)
                : (isPartiallyPaid
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(
              color: isFullyPaid
                  ? VSPColors.accent.withValues(alpha: 0.3)
                  : (isPartiallyPaid
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isFullyPaid
                    ? Iconsax.tick_circle_copy
                    : (isPartiallyPaid ? Iconsax.receipt_2_copy : Iconsax.money_copy),
                color: isFullyPaid
                    ? VSPColors.accent
                    : (isPartiallyPaid ? const Color(0xFF38BDF8) : VSPColors.textSecondary),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFullyPaid
                      ? (isAr
                          ? 'تم دفع الحجز بالكامل مسبقاً (${totalPrice.toInt()} ج.م)'
                          : 'Fully Paid in Advance (${totalPrice.toInt()} EGP)')
                      : (isPartiallyPaid
                          ? (isAr
                              ? 'عربون مسدد: ${currentPaidAmount.toInt()} ج.م • المتبقي عند الحضور: ${remainingBalance.toInt()} ج.م'
                              : 'Deposit: ${currentPaidAmount.toInt()} EGP • Remaining: ${remainingBalance.toInt()} EGP')
                          : (isAr
                              ? 'حجز كاش مؤكد • التحصيل بالكامل عند الحضور (${totalPrice.toInt()} ج.م)'
                              : 'Cash Booking • Collect ${totalPrice.toInt()} EGP on arrival')),
                  style: TextStyle(
                    color: isFullyPaid
                        ? VSPColors.accent
                        : (isPartiallyPaid ? const Color(0xFF38BDF8) : Colors.white70),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
