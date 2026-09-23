import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class OwnerTimePeriodDropdown extends StatelessWidget {
  final String selectedTimePeriod;
  final ValueChanged<String> onChanged;
  final bool isArabic;

  const OwnerTimePeriodDropdown({
    super.key,
    required this.selectedTimePeriod,
    required this.onChanged,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    const itemStyle = TextStyle(
      color: VSPColors.textPrimary,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    );

    final periods = [
      {'key': 'today', 'label': isArabic ? 'اليوم' : 'Today'},
      {'key': 'yesterday', 'label': isArabic ? 'أمس' : 'Yesterday'},
      {'key': 'week', 'label': isArabic ? 'الأسبوع' : 'This Week'},
      {'key': 'month', 'label': isArabic ? 'الشهر' : 'This Month'},
      {'key': 'all', 'label': isArabic ? 'الكل' : 'All Time'},
    ];

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedTimePeriod,
          dropdownColor: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.card),
          icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 13),
          style: itemStyle,
          selectedItemBuilder: (context) {
            return periods.map((p) {
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  p['label']!,
                  style: const TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList();
          },
          items: periods.map((p) {
            final isCurrent = selectedTimePeriod == p['key'];
            return DropdownMenuItem<String>(
              value: p['key'],
              child: Text(
                p['label']!,
                style: TextStyle(
                  color: isCurrent ? VSPColors.accent : VSPColors.textPrimary,
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              HapticFeedback.selectionClick();
              onChanged(val);
            }
          },
        ),
      ),
    );
  }
}
