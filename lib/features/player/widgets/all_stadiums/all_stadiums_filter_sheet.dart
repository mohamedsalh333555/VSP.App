import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../services/stadium_filter_sort_service.dart';

/// Modal bottom sheet allowing users to filter and sort stadiums by floor type and sorting order.
class AllStadiumsFilterSheet extends StatefulWidget {
  final StadiumSortOption initialSortOption;
  final String initialFloorType;
  final bool isArabic;
  final void Function(StadiumSortOption sortOption, String floorType) onApply;
  final VoidCallback onReset;

  const AllStadiumsFilterSheet({
    super.key,
    required this.initialSortOption,
    required this.initialFloorType,
    required this.isArabic,
    required this.onApply,
    required this.onReset,
  });

  /// Displays the modal bottom sheet and awaits user confirmation.
  static Future<void> show({
    required BuildContext context,
    required StadiumSortOption initialSortOption,
    required String initialFloorType,
    required bool isArabic,
    required void Function(StadiumSortOption sortOption, String floorType) onApply,
    required VoidCallback onReset,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: VSPColors.surface,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AllStadiumsFilterSheet(
        initialSortOption: initialSortOption,
        initialFloorType: initialFloorType,
        isArabic: isArabic,
        onApply: onApply,
        onReset: onReset,
      ),
    );
  }

  @override
  State<AllStadiumsFilterSheet> createState() => _AllStadiumsFilterSheetState();
}

class _AllStadiumsFilterSheetState extends State<AllStadiumsFilterSheet> {
  late StadiumSortOption _sortOption;
  late String _floorType;

  @override
  void initState() {
    super.initState();
    _sortOption = widget.initialSortOption;
    _floorType = widget.initialFloorType;
  }

  Widget _buildSortChip(StadiumSortOption option, String label) {
    final isSelected = _sortOption == option;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: VSPColors.accent,
      backgroundColor: VSPColors.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isSelected ? VSPColors.accent : VSPColors.divider),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _sortOption = option);
        }
      },
    );
  }

  Widget _buildFloorChip(String floorType, String label) {
    final isSelected = _floorType.toLowerCase() == floorType.toLowerCase();
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: VSPColors.accent,
      backgroundColor: VSPColors.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isSelected ? VSPColors.accent : VSPColors.divider),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _floorType = floorType);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isArabic ? 'تصفية وترتيب الملاعب' : 'Filter & Sort Stadiums',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  widget.onReset();
                  Navigator.pop(context);
                },
                child: Text(widget.isArabic ? 'إعادة ضبط' : 'Reset', style: const TextStyle(color: VSPColors.accent)),
              ),
            ],
          ),
          const Divider(color: VSPColors.divider),
          const SizedBox(height: 12),

          // Sort Options
          Text(
            widget.isArabic ? 'ترتيب حسب:' : 'Sort By:',
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSortChip(StadiumSortOption.featured, widget.isArabic ? 'المميزة' : 'Featured'),
              _buildSortChip(StadiumSortOption.topRated, widget.isArabic ? 'الأعلى تقييماً' : 'Top Rated'),
              _buildSortChip(StadiumSortOption.priceLowToHigh, widget.isArabic ? 'الأقل سعراً' : 'Lowest Price'),
              _buildSortChip(StadiumSortOption.priceHighToLow, widget.isArabic ? 'الأعلى سعراً' : 'Highest Price'),
            ],
          ),

          const SizedBox(height: 20),

          // Floor Type Options
          Text(
            widget.isArabic ? 'نوع الأرضية:' : 'Pitch / Floor Type:',
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFloorChip('All', widget.isArabic ? 'الكل' : 'All'),
              _buildFloorChip('نجيل صناعي', widget.isArabic ? 'نجيل صناعي' : 'Artificial Grass'),
              _buildFloorChip('نجيل طبيعي', widget.isArabic ? 'نجيل طبيعي' : 'Natural Grass'),
              _buildFloorChip('ترتان', widget.isArabic ? 'ترتان' : 'Tartan'),
              _buildFloorChip('صالة', widget.isArabic ? 'صالة مغطاة' : 'Indoor Court'),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_sortOption, _floorType);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
              ),
              child: Text(
                widget.isArabic ? 'تطبيق الفلترة' : 'Apply Filters',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}
