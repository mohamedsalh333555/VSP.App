import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

/// Card displaying the registration fee and the official tournament prize.
class League1v1PrizeCard extends StatelessWidget {
  final double entryFee;
  final double prizeAmount;
  final int registeredCount;
  final bool isArabic;

  const League1v1PrizeCard({
    super.key,
    required this.entryFee,
    required this.prizeAmount,
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
        borderRadius: BorderRadius.circular(VSPRadius.card),
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
                borderRadius: BorderRadius.circular(VSPRadius.card),
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
                    entryFee > 0
                        ? '${entryFee.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}'
                        : (isArabic ? 'غير متاح' : 'Unavailable'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic ? 'رسوم الاشتراك' : 'Registration fee',
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
                color: VSPColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(VSPRadius.card),
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
                        isArabic ? 'الجائزة' : 'Prize',
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
                    prizeAmount > 0
                        ? '${prizeAmount.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}'
                        : (isArabic ? 'غير متاح' : 'Unavailable'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'isArabic ? 'الجائزة الرسمية للبطل' : 'Official winner prize'',
                    style: const TextStyle(
                      color: VSPColors.success,
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
