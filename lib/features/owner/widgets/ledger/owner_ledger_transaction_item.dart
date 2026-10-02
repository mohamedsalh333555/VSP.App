import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Single transaction item row in owner financial ledger.
class OwnerLedgerTransactionItem extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final bool isAr;

  const OwnerLedgerTransactionItem({
    super.key,
    required this.transaction,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final type = transaction['type']?.toString().trim() ?? '';
    if (type.isEmpty) return const SizedBox.shrink();
    final method = transaction['payment_method']?.toString().trim() ?? '';
    final amountVal = transaction['amount'] ?? 0;
    final double amount = (amountVal is num) ? amountVal.toDouble() : 0.0;
    final dateStr = transaction['created_at'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    if (date == null) return const SizedBox.shrink();

    final String title;
    final String amountText;

    if (type == 'match_win') {
      title = isAr ? 'مكافأة فوز بمباراة' : 'Match Win Reward';
      amountText = isAr ? '+3 نقاط' : '+3 pts';
    } else if (type == 'payout_disbursed' || type == 'payout') {
      title = isAr ? 'سحب أرباح مكتمل' : 'Payout Disbursed';
      amountText = '-${amount.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}';
    } else if (type == 'payout_pending') {
      title = isAr ? 'طلب سحب قيد المراجعة' : 'Payout Pending';
      amountText = '-${amount.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}';
    } else if (type == 'payout_rejected') {
      title = isAr ? 'طلب سحب مرفوض (مسترد)' : 'Payout Rejected (Restored)';
      amountText = '${amount.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}';
    } else if (type == 'digital' || type == 'online' || method == 'paymob') {
      title = isAr ? 'تحصيل إلكتروني آمن' : 'Digital Online Payment';
      amountText = '+${amount.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}';
    } else {
      title = isAr ? 'عملية مالية' : 'Financial Transaction';
      amountText = '${amount.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}';
    }

    String formattedDate;
    try {
      formattedDate = DateFormat('yyyy/MM/dd — hh:mm a', isAr ? 'ar' : 'en').format(date.toLocal());
    } catch (_) {
      formattedDate = DateFormat('yyyy/MM/dd — hh:mm a').format(date.toLocal());
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  formattedDate,
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            amountText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ).merge(VSPTypography.numericStyle),
          ),
        ],
      ),
    );
  }
}
