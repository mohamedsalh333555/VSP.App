import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/paymob_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

/// Card showing the full transparent financial breakdown, stadium timing details, and service fees.
class PaymentBreakdownCard extends StatelessWidget {
  final BookingDraft bookingDraft;
  final bool isChampionship;
  final bool hasDeposit;
  final double amountToPay;
  final bool isArabic;

  const PaymentBreakdownCard({
    super.key,
    required this.bookingDraft,
    required this.isChampionship,
    required this.hasDeposit,
    required this.amountToPay,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final double serviceFee = PaymobService.calculateServiceFee(amountToPay);
    final double totalWithFees = PaymobService.calculateTotalAmount(amountToPay);

    final String displayStadiumName =
        (bookingDraft.stadiumName.trim().isEmpty || bookingDraft.stadiumName.trim() == 'Mo')
            ? (isArabic ? 'الملعب الرئيسي' : 'Main Pitch')
            : bookingDraft.stadiumName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isChampionship ? Iconsax.cup_copy : Iconsax.building_copy,
                  color: VSPColors.textSecondary, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayStadiumName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Iconsax.calendar_1_copy, color: VSPColors.textSecondary, size: 14),
              const SizedBox(width: 8),
              Text(
                DateFormat('yyyy/MM/dd').format(bookingDraft.startTime),
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 14),
              const Icon(Iconsax.clock_copy, color: VSPColors.textSecondary, size: 14),
              const SizedBox(width: 6),
              Text(
                DateFormat('hh:mm a').format(bookingDraft.startTime),
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const Divider(color: VSPColors.divider, height: 20),
          _buildFeeRow(
            label: isChampionship
                ? (isArabic ? 'رسوم اشتراك البطولة' : 'Championship Entry Fee')
                : (hasDeposit
                    ? (isArabic ? 'عربون حجز الملعب' : 'Stadium Deposit')
                    : (isArabic ? 'إجمالي سعر حجز الملعب' : 'Stadium Total Price')),
            value: '${amountToPay.toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
            isBold: false,
          ),
          const SizedBox(height: 6),
          _buildFeeRow(
            label: isArabic ? 'رسوم خدمات المنصة' : 'Platform Service Fee',
            value: '${serviceFee.toStringAsFixed(1)} ${isArabic ? 'ج.م' : 'EGP'}',
            isBold: false,
            onInfoTap: () => showFeeTransparencyModal(context, isArabic),
          ),
          const SizedBox(height: 6),
          _buildFeeRow(
            label: isArabic ? 'إجمالي الدفع النهائي' : 'Total Checkout Amount',
            value: '${totalWithFees.toStringAsFixed(1)} ${isArabic ? 'ج.م' : 'EGP'}',
            isBold: true,
          ),
          if (hasDeposit && (bookingDraft.totalPrice - amountToPay) > 0) ...[
            const SizedBox(height: 6),
            _buildFeeRow(
              label: isArabic ? 'المتبقي وسداده كاش بالملعب' : 'Remaining Pay at Pitch',
              value: '${(bookingDraft.totalPrice - amountToPay).toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
            ),
          ],
        ],
      ),
    );
  }

  static void showFeeTransparencyModal(BuildContext context, bool isArabic) {
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
                    ? 'رسوم خدمات المنصة تغطي تكاليف المعاملات البنكية المشفرة، والتثبيت الذري الفوري للمواعيد (منع التكرار)، وخدمة العملاء والدعم الفني المباشر على مدار الساعة.'
                    : 'The platform service fee covers end-to-end encrypted payment processing, instant atomic slot locking (zero double-bookings), and 24/7 priority customer support.',
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

  Widget _buildFeeRow({
    required String label,
    required String value,
    bool isBold = false,
    VoidCallback? onInfoTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isBold ? Colors.white : VSPColors.textSecondary,
                fontSize: isBold ? 13 : 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (onInfoTap != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onInfoTap,
                child: const Icon(
                  Iconsax.info_circle_copy,
                  size: 14,
                  color: VSPColors.accent,
                ),
              ),
            ],
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? VSPColors.accent : Colors.white,
            fontSize: isBold ? 14 : 11,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
