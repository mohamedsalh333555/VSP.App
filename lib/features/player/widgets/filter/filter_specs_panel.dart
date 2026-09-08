import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class FilterSpecsPanel extends StatelessWidget {
  final Map<String, bool> sizeFilters;
  final bool isArabic;
  final void Function(String key, bool val) onToggleSize;

  const FilterSpecsPanel({
    super.key,
    required this.sizeFilters,
    required this.isArabic,
    required this.onToggleSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'سعة الملعب' : 'Pitch Capacity',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sizeFilters.entries.map((entry) {
            final isSelected = entry.value;
            final label = isArabic
                ? (entry.key == '5 VS 5'
                    ? 'خماسي (5v5)'
                    : (entry.key == '7 VS 7' ? 'سباعي (7v7)' : '11v11'))
                : entry.key;

            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (val) => onToggleSize(entry.key, val),
              selectedColor: VSPColors.accent.withValues(alpha: 0.15),
              checkmarkColor: VSPColors.accent,
              side: BorderSide(color: isSelected ? VSPColors.accent : VSPColors.divider),
              labelStyle: TextStyle(
                color: isSelected ? VSPColors.accent : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
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
