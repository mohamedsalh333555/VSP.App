import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class FilterCategorySidebar extends StatelessWidget {
  final String selectedCategory;
  final bool isArabic;
  final Map<String, String> categoryTitles;
  final Map<String, IconData> categoryIcons;
  final int Function(String key) getBadgeCount;
  final ValueChanged<String> onSelectCategory;

  const FilterCategorySidebar({
    super.key,
    required this.selectedCategory,
    required this.isArabic,
    required this.categoryTitles,
    required this.categoryIcons,
    required this.getBadgeCount,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isArabic ? 135 : 125,
      decoration: const BoxDecoration(
        color: VSPColors.surfaceAlt,
        border: BorderDirectional(
          end: BorderSide(
            color: VSPColors.divider,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: categoryTitles.keys.map((key) {
            final isSelected = selectedCategory == key;
            final badgeCount = getBadgeCount(key);
            final title = categoryTitles[key] ?? key;
            final icon = categoryIcons[key] ?? Icons.category;

            return InkWell(
              onTap: () => onSelectCategory(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                decoration: BoxDecoration(
                  color: isSelected ? VSPColors.surface : Colors.transparent,
                  border: BorderDirectional(
                    start: BorderSide(
                      color: isSelected ? VSPColors.accent : Colors.transparent,
                      width: 3.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: VSPColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
