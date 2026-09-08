import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class FilterAmenitiesPanel extends StatelessWidget {
  final Map<String, bool> amenitiesFilters;
  final bool isArabic;
  final void Function(String key, bool val) onToggleAmenity;

  const FilterAmenitiesPanel({
    super.key,
    required this.amenitiesFilters,
    required this.isArabic,
    required this.onToggleAmenity,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'المرافق المتاحة بالملعب' : 'Available Amenities',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: amenitiesFilters.entries.map((entry) {
            final isSelected = entry.value;
            return FilterChip(
              label: Text(entry.key),
              selected: isSelected,
              onSelected: (val) => onToggleAmenity(entry.key, val),
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
