import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

/// Card displaying the transparent breakdown between registration entry fee and live accumulated prize pool.
class League1v1PrizeCard extends StatelessWidget {
  final double entryFee;
  final double prizePool;
  final int registeredCount;
  final bool isArabic;

  const League1v1PrizeCard({
    super.key,
    required this.entryFee,
    required this.prizePool,
    required this.registeredCount,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          // Entry Fee Column
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: VSPColors.divider.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.ticket_copy, size: 15, color: VSPColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        isArabic ? 'رسوم الاشتراك' : 'Entry Fee',
                        style: const TextStyle(
                          color: VSPColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${entryFee.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic ? 'دفع إلكتروني إلزامي' : 'Mandatory e-pay',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Prize Pool Column (Live Accumulator)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF162512),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.moneys_copy, size: 15, color: VSPColors.accent),
                      const SizedBox(width: 6),
                      Text(
                        isArabic ? 'الجائزة التراكمية' : 'Live Prize Pool',
                        style: const TextStyle(
                          color: VSPColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${prizePool.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$registeredCount ${isArabic ? "دفعوا واشتركوا" : "paid entries"}',
                    style: const TextStyle(
                      color: Color(0xFF86EFAC),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
