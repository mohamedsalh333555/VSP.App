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
  final PaymobFeePolicy? feePolicy;
  final bool isFeePolicyLoading;
  final VoidCallback onRetryFeePolicy;

  const PaymentBreakdownCard({
    super.key,
    required this.bookingDraft,
    required this.isChampionship,
    required this.hasDeposit,
    required this.amountToPay,
    required this.isArabic,
    required this.feePolicy,
    required this.isFeePolicyLoading,
    required this.onRetryFeePolicy,
  });

  @override
  Widget build(BuildContext context) {
    if (isFeePolicyLoading) {
      return _buildFeePolicyState(context, isLoading: true);
    }
    final policy = feePolicy;
    if (policy == null || !policy.isValidForElectronicCheckout) {
      return _buildFeePolicyState(context, isLoading: false);
    }

    final double serviceFee = policy.serviceFee(amountToPay);
    final double totalWithFees = policy.total(amountToPay);

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
                  style: const TextStyle(color: VSPColors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
            label: isArabic ? 'مصاريف إدارية' : 'Administrative Fee',
            value: '${serviceFee.toStringAsFixed(1)} ${isArabic ? 'ج.م' : 'EGP'}',
            isBold: false,
            onInfoTap: () => showFeeTransparencyModal(context, isArabic),
            infoTooltip: isArabic ? 'تفاصيل المصاريف الإدارية' : 'Fee details',
          ),
          const SizedBox(height: 6),
          _buildFeeRow(
            label: isArabic ? 'إجمالي المطلوب دفعه الآن' : 'Total Amount Due Now',
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

  Widget _buildFeePolicyState(BuildContext context, {required bool isLoading}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: isLoading ? VSPColors.divider : VSPColors.warning),
      ),
      child: Row(
        children: [
          Icon(
            isLoading ? Iconsax.timer_1_copy : Iconsax.info_circle_copy,
            color: isLoading ? VSPColors.textSecondary : VSPColors.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isLoading
                  ? (isArabic ? 'جارٍ تحميل تفاصيل الرسوم...' : 'Loading fee details...')
                  : (isArabic
                      ? 'تعذر التحقق من رسوم الدفع. لن نعرض إجماليًا غير مؤكد؛ أعد المحاولة قبل الدفع.'
                      : 'Could not verify payment fees. An unconfirmed total is hidden; retry before paying.'),
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
          ),
          if (!isLoading)
            TextButton(
              onPressed: onRetryFeePolicy,
              child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
            ),
        ],
      ),
    );
  }

  static void showFeeTransparencyModal(BuildContext context, bool isArabic) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
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
                    isArabic ? 'تفاصيل المصاريف الإدارية' : 'Administrative Fee Details',
                    style: const TextStyle(color: VSPColors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isArabic
                    ? 'تتكوّن المصاريف الإدارية من رسوم المنصة ورسوم معالجة الدفع الإلكتروني، ويتم حسابها وفق سياسة الرسوم الحالية قبل تأكيد الدفع.'
                    : 'Administrative fees combine the VSP platform fee and Paymob processing fee, calculated from the current fee policy before checkout.',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13.5, height: 1.6),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: VSPColors.black,
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
    String? infoTooltip,
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
                color: isBold ? VSPColors.white : VSPColors.textSecondary,
                fontSize: isBold ? 13 : 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (onInfoTap != null) ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: infoTooltip,
                onPressed: onInfoTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(
                  Iconsax.info_circle_copy,
                  size: 16,
                  color: VSPColors.accent,
                ),
              ),
            ],
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? VSPColors.accent : VSPColors.white,
            fontSize: isBold ? 14 : 11,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
