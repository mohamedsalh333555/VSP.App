import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

class League1v1HeroCard extends StatelessWidget {
  final String tourneyName; final String? governorate; final String status;
  final String? scheduledAt; final int registeredCount; final int targetCount;
  final int remainingCount; final double progress; final bool isArabic;
  const League1v1HeroCard({super.key, required this.tourneyName, required this.governorate, required this.status, required this.scheduledAt, required this.registeredCount, required this.targetCount, required this.remainingCount, required this.progress, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final location = governorate?.trim().isNotEmpty == true ? governorate!.trim() : (isArabic ? 'المحافظة غير محددة' : 'Location not set');
    final d = scheduledAt == null ? null : DateTime.tryParse(scheduledAt!);
    final date = d == null ? (isArabic ? 'الموعد يحدد لاحقًا' : 'Date to be announced') : d!.day.toString().padLeft(2,'0') + '/' + d.month.toString().padLeft(2,'0') + ' • ' + d.hour.toString().padLeft(2,'0') + ':' + d.minute.toString().padLeft(2,'0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.card), border: Border.all(color: VSPColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: VSPColors.surfaceAlt, borderRadius: BorderRadius.circular(VSPRadius.md)), child: const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 21)),
          const SizedBox(width: 12),
          Expanded(child: Text(tourneyName.isEmpty ? (isArabic ? 'بطولة 1 ضد 1' : '1v1 Tournament') : tourneyName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: VSPColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 14), const Divider(color: VSPColors.divider, height: 1), const SizedBox(height: 12),
        _row(Iconsax.location_copy, isArabic ? 'المحافظة' : 'Location', location),
        const SizedBox(height: 8),
        _row(Iconsax.calendar_1_copy, isArabic ? 'الموعد' : 'Date', date),
        const SizedBox(height: 8),
        _row(Iconsax.profile_2user_copy, isArabic ? 'المسجلون' : 'Players', targetCount > 0 ? registeredCount.toString() + ' / ' + targetCount.toString() : registeredCount.toString()),
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value) => Row(children: [
    Icon(icon, size: 17, color: VSPColors.textSecondary), const SizedBox(width: 9),
    Text(label, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
    const Spacer(),
    Flexible(child: Text(value, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w800))),
  ]);
}
