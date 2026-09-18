import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Card displaying withdrawable digital balance and payout action.
class OwnerDigitalBalanceCard extends StatelessWidget {
  final double digitalBalance;
  final double escrowBalance;
  final bool isAr;
  final VoidCallback onRequestPayout;

  const OwnerDigitalBalanceCard({
    super.key,
    required this.digitalBalance,
    this.escrowBalance = 0.0,
    required this.isAr,
    required this.onRequestPayout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAr ? 'مستحقات قابلة للتحويل' : 'Withdrawable earnings',
                    style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
                  ),
                ],
              ),
              Text(
                '${digitalBalance.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          if (escrowBalance > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.clock_copy, size: 14, color: VSPColors.accent),
                      const SizedBox(width: 6),
                      Text(
                        isAr ? 'أرباح مباريات قادمة (قيد الضمان):' : 'Upcoming matches (Escrow):',
                        style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
                      ),
                    ],
                  ),
                  Text(
                    '${escrowBalance.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
                    style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
          if (digitalBalance > 0) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onRequestPayout,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: VSPColors.accent,
                  borderRadius: BorderRadius.circular(12),
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
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? 'إجمالي التحصيل النقدي' : 'Pitch Cash Collected',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              Text(
                isAr ? 'تم استلامها كاش بالملعب' : 'Received in cash at pitch',
                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11),
              ),
            ],
          ),
          Text(
            '${pitchCash.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
