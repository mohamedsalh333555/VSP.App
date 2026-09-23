import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/services/platform_fee_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class CheckoutFinancialCard extends StatefulWidget {
  final double entryFee;

  const CheckoutFinancialCard({
    super.key,
    required this.entryFee,
  });

  @override
  State<CheckoutFinancialCard> createState() => _CheckoutFinancialCardState();
}

class _CheckoutFinancialCardState extends State<CheckoutFinancialCard> {
  late final Future<PlatformFeeConfig> _feeConfigFuture;

  @override
  void initState() {
    super.initState();
    _feeConfigFuture = PlatformFeeService().getBookingFeeConfig();
  }

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
                  Expanded(
                    child: Text(
                      isArabic ? 'شفافية رسوم الدفع' : 'Payment Fee Transparency',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isArabic
                    ? 'الرسوم تُحتسب من قيمة الاشتراك الأساسية وتشمل عمولة VSP ورسوم بوابة الدفع. المبلغ النهائي يحدده الخادم عند إنشاء عملية الدفع.'
                    : 'Fees are calculated from the base registration amount and include the VSP commission and payment gateway fee. The server determines the final checkout amount.',
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

  Widget _row(String label, String value, {bool bold = false, VoidCallback? info}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: bold ? Colors.white : VSPColors.textSecondary,
                    fontSize: bold ? 15 : 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (info != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: info,
                  child: const Icon(Iconsax.info_circle_copy, size: 14, color: VSPColors.accent),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: bold ? VSPColors.accent : Colors.white,
            fontSize: bold ? 18 : 13,
            fontWeight: bold ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return FutureBuilder<PlatformFeeConfig>(
      future: _feeConfigFuture,
      builder: (context, snapshot) {
        final feeConfig = snapshot.data;
        final vspFee = feeConfig?.calculateVspFee(widget.entryFee) ?? 0;
        final gatewayFee = feeConfig?.calculateGatewayFee(widget.entryFee, 'card') ?? 0;
        final serviceFee = feeConfig?.calculateTotalFees(widget.entryFee, 'card');
        final total = feeConfig?.calculateTotalAmount(widget.entryFee, 'card');

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
                isArabic ? 'تفاصيل الرسوم والاشتراك' : 'Registration & Fee Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Divider(color: VSPColors.divider, height: 20),
              _row(isArabic ? 'رسوم اشتراك البطولة' : 'Tournament Entry Fee', '${widget.entryFee.toStringAsFixed(2)} ج.م'),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting)
                _row(isArabic ? 'رسوم الدفع' : 'Payment Fees', isArabic ? 'جاري الحساب…' : 'Calculating…')
              else if (feeConfig == null)
                _row(isArabic ? 'رسوم الدفع' : 'Payment Fees', isArabic ? 'تُحتسب تلقائياً' : 'Calculated automatically', info: () => _showFeeTransparencyModal(context, isArabic))
              else ...[
                _row(isArabic ? 'عمولة VSP' : 'VSP Commission', '${vspFee.toStringAsFixed(2)} ج.م'),
                const SizedBox(height: 8),
                _row(isArabic ? 'رسوم بوابة الدفع' : 'Payment Gateway Fee', '${gatewayFee.toStringAsFixed(2)} ج.م'),
                const SizedBox(height: 8),
                _row(isArabic ? 'إجمالي رسوم الدفع' : 'Total Payment Fees', '${serviceFee!.toStringAsFixed(2)} ج.م'),
                const Divider(color: VSPColors.divider, height: 20),
                _row(isArabic ? 'المبلغ الإجمالي المطلوب' : 'Total Amount', '${total!.toStringAsFixed(2)} ج.م', bold: true, info: () => _showFeeTransparencyModal(context, isArabic)),
              ],
            ],
          ),
        );
      },
    );
  }
}
