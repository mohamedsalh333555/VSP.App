import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Duration selector component for owner booking management.
/// Provides choice chips, custom +/- 30-minute adjustments, and constraint indications.
class BookingSheetDurationSelector extends StatelessWidget {
  final int selectedMinutes;
  final int maxMins;
  final bool isCompletedBooking;
  final ValueChanged<int> onDurationChanged;

  const BookingSheetDurationSelector({
    super.key,
    required this.selectedMinutes,
    required this.maxMins,
    required this.isCompletedBooking,
    required this.onDurationChanged,
  });

  static String formatDurationLabel(int mins, bool isArabic) {
    final double hours = mins / 60.0;
    if (hours == 0.5) return isArabic ? '30 دقيقة' : '30 Mins';
    if (hours == 1.0) return isArabic ? 'ساعة واحدة' : '1 Hour';
    if (hours == 1.5) return isArabic ? 'ساعة ونصف' : '1.5 Hours';
    if (hours == 2.0) return isArabic ? 'ساعتين' : '2 Hours';
    if (hours == 2.5) return isArabic ? 'ساعتين ونصف' : '2.5 Hours';
    if (hours == 3.0) return isArabic ? '3 ساعات' : '3 Hours';
    if (hours == 4.0) return isArabic ? '4 ساعات' : '4 Hours';
    if (hours.remainder(1.0) == 0) {
      return isArabic ? '${hours.toInt()} ساعات' : '${hours.toInt()} Hours';
    }
    return isArabic ? '${hours.toStringAsFixed(1)} ساعة' : '$hours Hours';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final allOptions = [
      {'label': isArabic ? 'ساعة' : '1 Hr', 'value': 60},
      {'label': isArabic ? 'ساعة ونصف' : '1.5 Hrs', 'value': 90},
      {'label': isArabic ? 'ساعتين' : '2 Hrs', 'value': 120},
      {'label': isArabic ? 'ساعتين ونصف' : '2.5 Hrs', 'value': 150},
      {'label': isArabic ? '3 ساعات' : '3 Hrs', 'value': 180},
      {'label': isArabic ? '4 ساعات' : '4 Hrs', 'value': 240},
    ];

    final availableOptions =
        allOptions.where((opt) => (opt['value'] as int) <= maxMins).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: availableOptions.map((opt) {
              final val = opt['value'] as int;
              final isSelected = selectedMinutes == val;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(opt['label'] as String),
                  selected: isSelected,
                  onSelected: isCompletedBooking
                      ? null
                      : (_) => onDurationChanged(val),
                  selectedColor: VSPColors.accent,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : VSPColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  backgroundColor: VSPColors.surfaceAlt,
                  shape: const StadiumBorder(),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'مدة مخصصة:' : 'Custom Duration:',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
            Container(
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.minus_cirlce_copy,
                        size: 16, color: VSPColors.textPrimary),
                    onPressed: (isCompletedBooking || selectedMinutes <= 30)
                        ? null
                        : () => onDurationChanged(selectedMinutes - 30),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      formatDurationLabel(selectedMinutes, isArabic),
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.add_circle_copy,
                        size: 16, color: VSPColors.textPrimary),
                    onPressed: (isCompletedBooking || selectedMinutes + 30 > maxMins)
                        ? null
                        : () => onDurationChanged(selectedMinutes + 30),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (maxMins < 720) ...[
          const SizedBox(height: 6),
          Text(
            isArabic
                ? ' الحد الأقصى المتاح حتى الموعد القادم/الإغلاق: ${formatDurationLabel(maxMins, isArabic)}'
                : ' Max available until next booking/closing: ${formatDurationLabel(maxMins, isArabic)}',
            style: const TextStyle(
                color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }
}
