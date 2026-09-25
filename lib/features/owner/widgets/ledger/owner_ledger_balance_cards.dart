import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Card displaying withdrawable digital balance and payout action.
class OwnerDigitalBalanceCard extends StatelessWidget {
  final double digitalBalance;
  final bool isAr;
  final VoidCallback onRequestPayout;
  /// عدد الحجوزات المكتملة (اختياري — يُعرض كشرح للرصيد)
  final int? completedBookingsCount;
  /// المسحوب مسبقاً (اختياري — يُعرض كشرح)
  final double? totalWithdrawn;

  const OwnerDigitalBalanceCard({
    super.key,
    required this.digitalBalance,
    required this.isAr,
    required this.onRequestPayout,
    this.completedBookingsCount,
    this.totalWithdrawn,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasDetails = (completedBookingsCount != null && completedBookingsCount! > 0) ||
        (totalWithdrawn != null && totalWithdrawn! > 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'الرصيد الإلكتروني المتاح' : 'Available Digital Balance',
                    style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAr ? 'مستحقات قابلة للتحويل' : 'Withdrawable earnings',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              Text(
                '${digitalBalance.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          // ✅ سطر توضيحي يشرح مصدر الرصيد لتجنب قلق المالك
          if (hasDetails) ...{
            const SizedBox(height: 6),
            _buildSourceHint(),
          },
          if (digitalBalance > 0) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onRequestPayout,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: VSPColors.accent,
                  borderRadius: BorderRadius.circular(VSPRadius.input),
                ),
                child: Center(
                  child: Text(
                    isAr ? 'طلب تسوية وسحب الرصيد' : 'Request Payout Settlement',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceHint() {
    final parts = <String>[];
    if (completedBookingsCount != null && completedBookingsCount! > 0) {
      parts.add(isAr
          ? 'من ${completedBookingsCount!} حجز مكتمل'
          : 'from $completedBookingsCount completed booking${completedBookingsCount! > 1 ? 's' : ''}');
    }
    if (totalWithdrawn != null && totalWithdrawn! > 0) {
      parts.add(isAr
          ? 'بعد خصم ${totalWithdrawn!.toStringAsFixed(0)} ج.م تم سحبها مسبقاً'
          : 'after ${totalWithdrawn!.toStringAsFixed(0)} EGP previously withdrawn');
    }
    final hint = parts.join(' — ');
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        hint,
        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
      ),
    );
  }
}

/// Card displaying pitch cash collected on-site.
class OwnerPitchCashCard extends StatelessWidget {
  final double pitchCash;
  final bool isAr;

  const OwnerPitchCashCard({
    super.key,
    required this.pitchCash,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? 'إجمالي التحصيل النقدي' : 'Pitch Cash Collected',
                style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              Text(
                isAr ? 'تم استلامها كاش بالملعب' : 'Received in cash at pitch',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          Text(
            '${pitchCash.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
