import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class FilterSportsPanel extends StatelessWidget {
  final Map<String, bool> sportsFilters;
  final bool isArabic;
  final void Function(String key, bool selected) onToggleSport;

  const FilterSportsPanel({
    super.key,
    required this.sportsFilters,
    required this.isArabic,
    required this.onToggleSport,
  });

  @override
  Widget build(BuildContext context) {
    if (sportsFilters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          isArabic ? 'جاري تحميل أنواع الرياضات...' : 'Loading sports...',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sportsFilters.entries.map((entry) {
            final isSelected = entry.value;
            final String rawName = entry.key;
            final String label = rawName.toLowerCase() == 'football'
                ? (isArabic ? 'كرة القدم' : 'Football')
                : rawName.toLowerCase() == 'padel'
                    ? (isArabic ? 'بادل' : 'Padel')
                    : rawName;

            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) => onToggleSport(entry.key, selected),
              selectedColor: VSPColors.accent.withValues(alpha: 0.15),
              checkmarkColor: VSPColors.accent,
              side: BorderSide(color: isSelected ? VSPColors.accent : VSPColors.divider),
              labelStyle: TextStyle(
                color: isSelected ? VSPColors.accent : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12.5,
              ),
              backgroundColor: VSPColors.surfaceAlt,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            );
          }).toList(),
        ),
      ],
    );
  }
}
