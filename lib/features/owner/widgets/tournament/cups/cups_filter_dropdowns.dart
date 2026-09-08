import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

class CupsFilterDropdowns extends StatelessWidget {
  final List<String> availableSports;
  final String selectedSport;
  final ValueChanged<String> onSportChanged;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  const CupsFilterDropdowns({
    super.key,
    required this.availableSports,
    required this.selectedSport,
    required this.onSportChanged,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: _buildFilterDropdown(
              context,
              availableSports,
              selectedSport,
              (v) {
                if (v != null) onSportChanged(v);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFilterDropdown(
              context,
              const ['All', 'Cup', 'League', 'GroupsAndKnockout'],
              selectedCategory,
              (v) {
                if (v != null) onCategoryChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context,
    List<String> items,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    String translateItem(String val) {
      if (!isArabic) return val;
      if (val == 'All') return 'جميع البطولات';
      if (val == 'Cup') return 'كأس';
      if (val == 'League') return 'دوري';
      if (val == 'GroupsAndKnockout') return 'مجموعات وتصفيات';
      if (val == 'Football') return 'كرة القدم';
      if (val == 'Basketball') return 'كرة السلة';
      if (val == 'Padel') return 'بادل';
      if (val == 'Volleyball') return 'كرة الطائرة';
      if (val == 'Handball') return 'كرة اليد';
      return val;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 44,
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: VSPColors.surface,
          isExpanded: true,
          icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 16),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VSPColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                translateItem(item),
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
