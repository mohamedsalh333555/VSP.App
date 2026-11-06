import '../../../../../core/ui/components/vsp_filter_dropdown.dart';
import 'package:flutter/material.dart';
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
              isSport: true,
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
              isSport: false,
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
    ValueChanged<String?> onChanged, {
    bool isSport = false,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    String translateItem(String val) {
      if (!isArabic) return val;
      if (val == 'All') return isSport ? 'كافة الرياضات' : 'جميع البطولات';
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

    return VSPFilterDropdown<String>(
      value: value,
      items: items,
      labelFor: translateItem,
      onChanged: onChanged,
    );
  }
}
