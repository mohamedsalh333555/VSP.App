import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

import '../../../shared/widgets/primary_button.dart';

/// Filter Bottom Sheet Modal
class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String _selectedCategory = 'Sports';
  
  // Filter states
  final Map<String, bool> _sportsFilters = {
    'Foot Ball': true,
    'Basket Ball': false,
    'Volley Ball': false,
    'Hand Ball': false,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: VSPColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(VSPRadius.xl),
          topRight: Radius.circular(VSPRadius.xl),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: VSPColors.divider,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: VSPColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Content - Split View
          Expanded(
            child: Row(
              children: [
                // Left Sidebar - Categories
                Container(
                  width: 110,
                  decoration: const BoxDecoration(
                    color: VSPColors.surface,
                    border: Border(
                      right: BorderSide(
                        color: VSPColors.divider,
                        width: 1,
                      ),
                    ),
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildCategoryItem('Sports', Icons.sports_soccer),
                      _buildCategoryItem('Price Range', Icons.attach_money),
                      _buildCategoryItem('Time', Icons.access_time),
                      _buildCategoryItem('Ratings', Icons.star_outline),
                      _buildCategoryItem('Services', Icons.room_service),
                    ],
                  ),
                ),

                // Right Content Area
                Expanded(
                  child: Container(
                     padding: const EdgeInsets.all(VSPSpacing.md),
                    child: _buildContentForCategory(),
                  ),
                ),
              ],
            ),
          ),

          // Footer Buttons
          Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: VSPColors.divider,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: 'Reset',
                    onPressed: () {
                      setState(() {
                        _sportsFilters.updateAll((key, value) => false);
                      });
                    },
                    color: VSPColors.surfaceAlt,
                    textColor: VSPColors.textPrimary,
                  ),
                ),
                const SizedBox(width: VSPSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    text: 'Apply',
                    onPressed: () {
                      Navigator.pop(context, _sportsFilters);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String title, IconData icon) {
    final isSelected = _selectedCategory == title;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: VSPSpacing.md, horizontal: VSPSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent.withValues(alpha: 0.1) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? VSPColors.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentForCategory() {
    switch (_selectedCategory) {
      case 'Sports':
        return _buildSportsContent();
      case 'Price Range':
        return _buildPriceRangeContent();
      case 'Time':
        return _buildTimeContent();
      case 'Ratings':
        return _buildRatingsContent();
      case 'Services':
        return _buildServicesContent();
      default:
        return const SizedBox();
    }
  }

  Widget _buildSportsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Sports',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: VSPSpacing.md),
        ..._sportsFilters.entries.map((entry) {
          return Padding(
                  padding: const EdgeInsets.only(bottom: VSPSpacing.md),
            child: InkWell(
              onTap: () {
                setState(() {
                  _sportsFilters[entry.key] = !entry.value;
                });
              },
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: entry.value ? VSPColors.accent : Colors.transparent,
                      border: Border.all(
                        color: entry.value ? VSPColors.accent : VSPColors.textSecondary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                    child: entry.value
                        ? const Icon(
                            Icons.check,
                            color: VSPColors.background,
                            size: 16,
                          )
                        : null,
                  ),
                  const SizedBox(width: VSPSpacing.sm),
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPriceRangeContent() {
    return const Center(
      child: Text(
        'Price Range filters coming soon',
        style: TextStyle(
          color: VSPColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTimeContent() {
    return const Center(
      child: Text(
        'Time filters coming soon',
        style: TextStyle(
          color: VSPColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildRatingsContent() {
    return const Center(
      child: Text(
        'Ratings filters coming soon',
        style: TextStyle(
          color: VSPColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildServicesContent() {
    return const Center(
      child: Text(
        'Services filters coming soon',
        style: TextStyle(
          color: VSPColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}
