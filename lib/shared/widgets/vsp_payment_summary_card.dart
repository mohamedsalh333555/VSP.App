import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';
import '../../core/utils/vsp_financial_formatter.dart';

/// Unified Financial Breakdown Card used across checkout, success, and booking details.
class VSPPaymentSummaryCard extends StatelessWidget {
  final double baseAmount;
  final double? playerVspFee;
  final double? gatewayFee;
  final double? totalAmount;
  final String? paymentStatus;
  final bool isArabic;

  const VSPPaymentSummaryCard({
    super.key,
    required this.baseAmount,
    this.playerVspFee,
    this.gatewayFee,
    this.totalAmount,
    this.paymentStatus,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTotal = totalAmount ??
        (baseAmount + (playerVspFee ?? 0) + (gatewayFee ?? 0));

    return Container(
      padding: const EdgeInsets.all(VSPDSSpacing.cardPadding),
      decoration: BoxDecoration(
        color: VSPDSSemanticColors.surface,
        borderRadius: BorderRadius.circular(VSPDSRadius.card),
        border: Border.all(color: VSPDSSemanticColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow(
            label: isArabic ? 'سعر الملعب الأساسي' : 'Base Pitch Price',
            value: VSPFinancialFormatter.formatCurrency(baseAmount, isArabic: isArabic),
          ),
          if (playerVspFee != null && playerVspFee! > 0) ...[
            const SizedBox(height: VSPDSSpacing.xs),
            _buildRow(
              label: isArabic ? 'عمولة منصة VSP (5%)' : 'VSP Platform Fee (5%)',
              value: VSPFinancialFormatter.formatCurrency(playerVspFee!, isArabic: isArabic),
            ),
          ],
          if (gatewayFee != null && gatewayFee! > 0) ...[
            const SizedBox(height: VSPDSSpacing.xs),
            _buildRow(
              label: isArabic ? 'رسوم بوابة الدفع الإلكتروني' : 'Payment Gateway Fee',
              value: VSPFinancialFormatter.formatCurrency(gatewayFee!, isArabic: isArabic),
            ),
          ],
          const Divider(color: VSPDSSemanticColors.border, height: VSPDSSpacing.lg),
          _buildRow(
            label: isArabic ? 'الإجمالي' : 'Total',
            value: VSPFinancialFormatter.formatCurrency(effectiveTotal, isArabic: isArabic),
            isTotal: true,
          ),
          if (paymentStatus != null && paymentStatus!.isNotEmpty) ...[
            const SizedBox(height: VSPDSSpacing.xs),
            _buildRow(
              label: isArabic ? 'حالة السداد' : 'Payment Status',
              value: VSPFinancialFormatter.localizePaymentStatus(paymentStatus!, isArabic: isArabic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required String value,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isTotal
                  ? VSPDSSemanticColors.textPrimary
                  : VSPDSSemanticColors.textSecondary,
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: VSPDSSpacing.xs),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                value,
                style: TextStyle(
                  color: isTotal
                      ? VSPDSSemanticColors.accent
                      : VSPDSSemanticColors.textPrimary,
                  fontSize: isTotal ? 15 : 12,
                  fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
