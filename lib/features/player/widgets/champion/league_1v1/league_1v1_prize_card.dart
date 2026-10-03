import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

class League1v1PrizeCard extends StatelessWidget {
  final double entryFee; final double prizePool; final int registeredCount; final bool isArabic;
  const League1v1PrizeCard({super.key, required this.entryFee, required this.prizePool, required this.registeredCount, required this.isArabic});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.card), border: Border.all(color: VSPColors.divider)),
    child: Row(children: [
      Expanded(child: _value(Iconsax.wallet_1_copy, isArabic ? 'رسوم الاشتراك' : 'Entry fee', entryFee > 0 ? entryFee.toStringAsFixed(0) + ' ' + (isArabic ? 'ج.م' : 'EGP') : (isArabic ? 'غير متاح' : 'Unavailable'))),
      Container(width: 1, height: 42, color: VSPColors.divider),
      Expanded(child: _value(Iconsax.cup_copy, isArabic ? 'الجائزة الحالية' : 'Prize pool', prizePool > 0 ? prizePool.toStringAsFixed(0) + ' ' + (isArabic ? 'ج.م' : 'EGP') : (isArabic ? 'تحدد لاحقًا' : 'To be announced'))),
    ]),
  );

  Widget _value(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(children: [
      Icon(icon, size: 18, color: VSPColors.textSecondary), const SizedBox(height: 6),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 3),
      Text(value, textAlign: TextAlign.center, style: const TextStyle(color: VSPColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w900)),
    ]),
  );
}
