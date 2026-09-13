import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class FilterLocationPanel extends StatelessWidget {
  final String? selectedGov;
  final bool isArabic;
  final ValueChanged<String?> onSelectGov;

  const FilterLocationPanel({
    super.key,
    required this.selectedGov,
    required this.isArabic,
    required this.onSelectGov,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'اختر المحافظة' : 'Select Governorate',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          height: 48,
          decoration: BoxDecoration(
            color: VSPColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selectedGov != null ? VSPColors.accent : VSPColors.divider,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedGov,
              hint: Text(
                isArabic ? 'عرض كل المحافظات' : 'All Governorates',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
              dropdownColor: VSPColors.surfaceAlt,
              icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 16),
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
              onChanged: onSelectGov,
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    isArabic ? 'كل المحافظات' : 'All Governorates',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontSize: 13),
                  ),
                ),
                ...EgyptGovernorates.allGovernorates.map((gov) {
                  return DropdownMenuItem<String>(
                    value: gov,
                    child: Text(
                      gov,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontSize: 13),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
