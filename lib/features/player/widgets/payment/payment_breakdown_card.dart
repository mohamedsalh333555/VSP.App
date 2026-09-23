import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/paymob_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

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
    return FutureBuilder<PaymobFeeBreakdown>(
      future: PaymobService.getFeeBreakdown(amountToPay),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _unavailable();
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final fees = snapshot.data!;
        final displayName = bookingDraft.stadiumName.trim().isEmpty ||
                bookingDraft.stadiumName.trim() == 'Mo'
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
                  Icon(
                    isChampionship ? Iconsax.cup_copy : Iconsax.building_copy,
                    color: VSPColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Iconsax.calendar_1_copy,
                      color: VSPColors.textSecondary, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy/MM/dd').format(bookingDraft.startTime),
                    style: const TextStyle(
                        color: VSPColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Iconsax.clock_copy,
                      color: VSPColors.textSecondary, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('hh:mm a').format(bookingDraft.startTime),
                    style: const TextStyle(
                        color: VSPColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const Divider(color: VSPColors.divider, height: 20),
              _feeRow(
                label: isChampionship
                    ? (isArabic
                        ? 'رسوم اشتراك البطولة'
                        : 'Championship Entry Fee')
                    : (hasDeposit
                        ? (isArabic
                            ? 'عربون حجز الملعب'
                            : 'Stadium Deposit')
                        : (isArabic
                            ? 'إجمالي سعر حجز الملعب'
                            : 'Stadium Total Price')),
                value: '${amountToPay.toStringAsFixed(2)} ${isArabic ? 'ج.م' : 'EGP'}',
              ),
              const SizedBox(height: 6),
              _feeRow(
                label: isArabic
                    ? 'رسوم خدمات المنصة والدفع'
                    : 'Platform & payment service fees',
                value: '${fees.totalFees.toStringAsFixed(2)} ${isArabic ? 'ج.م' : 'EGP'}',
                onInfoTap: () =>
                    _showFeeTransparencyModal(context, isArabic),
              ),
              const SizedBox(height: 6),
              _feeRow(
                label: isArabic
                    ? 'إجمالي الدفع النهائي'
                    : 'Total Checkout Amount',
                value: '${fees.totalAmount.toStringAsFixed(2)} ${isArabic ? 'ج.م' : 'EGP'}',
                isBold: true,
              ),
              if (hasDeposit && (bookingDraft.totalPrice - amountToPay) > 0) ...[
                const SizedBox(height: 6),
                _feeRow(
                  label: isArabic
                      ? 'المتبقي وسداده كاش بالملعب'
                      : 'Remaining Pay at Pitch',
                  value: '${(bookingDraft.totalPrice - amountToPay).toStringAsFixed(2)} ${isArabic ? 'ج.م' : 'EGP'}',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _unavailable() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Text(
          isArabic
              ? 'تعذر تحميل سياسة الرسوم الرسمية من الخادم، لذلك لن يتم عرض إجمالي دفع غير موثوق.'
              : 'The authoritative fee policy could not be loaded, so an unverified payment total is not shown.',
          style: const TextStyle(color: VSPColors.error, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );

  static Widget _feeRow({
    required String label,
    required String value,
    bool isBold = false,
    VoidCallback? onInfoTap,
  }) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isBold ? Colors.white : VSPColors.textSecondary,
                      fontSize: isBold ? 13 : 11,
                      fontWeight:
                          isBold ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (onInfoTap != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onInfoTap,
                    child: const Icon(Iconsax.info_circle_copy,
                        size: 14, color: VSPColors.accent),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: isBold ? VSPColors.accent : Colors.white,
              fontSize: isBold ? 14 : 11,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ],
      );

  static void _showFeeTransparencyModal(
      BuildContext context, bool isArabic) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VSPColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isArabic
                    ? 'شفافية رسوم خدمات المنصة'
                    : 'Platform Service Fee Transparency',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Text(
                isArabic
                    ? 'رسوم VSP والرسوم المتعاقد عليها مع Paymob تُحسب على قيمة كل عملية دفع فعلية، وليس على إجمالي الحجز عند الدفع الجزئي.'
                    : 'VSP and contracted Paymob fees are calculated on each actual payment transaction, not on the full booking value when a partial payment is made.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.6),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isArabic ? 'فهمت ذلك' : 'Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
