import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/paymob_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

/// Card showing the full transparent financial breakdown, stadium timing details, and service fees.
class PaymentBreakdownCard extends StatefulWidget {
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
  State<PaymentBreakdownCard> createState() => _PaymentBreakdownCardState();

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
                    isArabic ? 'تفاصيل الرسوم والعمولة' : 'Fee & Commission Details',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isArabic
                    ? 'تشمل الرسوم عمولة منصة VSP (5% من قيمة الحجز) لتأكيد الحجز الفوري وحماية المواعيد، بالإضافة إلى رسوم المعالجة البنكية لبوابة Paymob المعتمدة.'
                    : 'Fees include the 5% VSP platform fee for instant slot locking and support, plus certified Paymob gateway processing fees.',
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
}

class _PaymentBreakdownCardState extends State<PaymentBreakdownCard> {
  late Future<PaymobFeePolicy?> _policyFuture;

  @override
  void initState() {
    super.initState();
    _policyFuture = PaymobService.fetchFeePolicy();
  }

  void _retry() {
    setState(() {
      _policyFuture = PaymobService.fetchFeePolicy();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.isArabic;
    final amountToPay = widget.amountToPay;
    final isChampionship = widget.isChampionship;
    final hasDeposit = widget.hasDeposit;

    final String displayStadiumName =
        (widget.bookingDraft.stadiumName.trim().isEmpty || widget.bookingDraft.stadiumName.trim() == 'Mo')
            ? (isArabic ? 'الملعب الرئيسي' : 'Main Pitch')
            : widget.bookingDraft.stadiumName;

    return FutureBuilder<PaymobFeePolicy?>(
      future: _policyFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final policy = snapshot.data;
        final isError = !isLoading && (snapshot.hasError || policy == null);

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
                    DateFormat('yyyy/MM/dd').format(widget.bookingDraft.startTime),
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Iconsax.clock_copy, color: VSPColors.textSecondary, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('hh:mm a').format(widget.bookingDraft.startTime),
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
              const SizedBox(height: 8),
              if (isLoading)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'جاري احتساب الرسوم من السيرفر...' : 'Calculating server fees...',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    ),
                  ],
                )
              else if (isError)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: VSPColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                    border: Border.all(color: VSPColors.error.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isArabic
                              ? 'تعذر تحميل سياسة الرسوم المعتمدة.'
                              : 'Could not load fee policy.',
                          style: const TextStyle(color: VSPColors.textPrimary, fontSize: 11.5),
                        ),
                      ),
                      TextButton(
                        onPressed: _retry,
                        child: Text(
                          isArabic ? 'إعادة المحاولة' : 'Retry',
                          style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                _buildFeeRow(
                  label: isArabic ? 'عمولة المنصة (5%)' : 'Platform Fee (5%)',
                  value: '${policy!.platformFee(amountToPay).toStringAsFixed(2)} ${isArabic ? 'ج.م' : 'EGP'}',
                  isBold: false,
                  onInfoTap: () => PaymentBreakdownCard.showFeeTransparencyModal(context, isArabic),
                ),
                const SizedBox(height: 6),
                _buildFeeRow(
                  label: isArabic ? 'رسوم بوابة الدفع البنكية' : 'Payment Gateway Fee',
                  value: '${policy.gatewayFee(amountToPay).toStringAsFixed(2)} ${isArabic ? 'ج.م' : 'EGP'}',
                  isBold: false,
                ),
                const SizedBox(height: 6),
                _buildFeeRow(
                  label: isArabic ? 'إجمالي المطلوب دفعه الآن' : 'Total Amount Due Now',
                  value: '${policy.total(amountToPay).toStringAsFixed(2)} ${isArabic ? 'ج.م' : 'EGP'}',
                  isBold: true,
                ),
              ],
              if (hasDeposit && (widget.bookingDraft.totalPrice - amountToPay) > 0) ...[
                const SizedBox(height: 6),
                _buildFeeRow(
                  label: isArabic ? 'المتبقي وسداده كاش بالملعب' : 'Remaining Pay at Pitch',
                  value: '${(widget.bookingDraft.totalPrice - amountToPay).toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
                ),
              ],
            ],
          ),
        );
      },
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
