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
    for (var sport in VSPConstants.sports) sport: sport == 'Football',
  };

  RangeValues _priceRange = const RangeValues(0, 3000);
  int _selectedRating = 0;
  final Map<String, bool> _servicesFilters = {
    'Has Ball': false,
    'Has Seats': false,
    'Professional Lighting': false,
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
                      // _buildCategoryItem('Time', Icons.access_time), // Time hidden for now as per instructions focus
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
                        _priceRange = const RangeValues(0, 3000);
                        _selectedRating = 0;
                        _servicesFilters.updateAll((key, value) => false);
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
                      final filters = {
                        'sports': _sportsFilters,
                        'minPrice': _priceRange.start,
                        'maxPrice': _priceRange.end,
                        'minRating': _selectedRating,
                        'selectedServices': _servicesFilters,
                      };
                      Navigator.pop(context, filters);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Range (EGP)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: VSPSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_priceRange.start.round()} EGP', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
            Text('${_priceRange.end.round()} EGP', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
          ],
        ),
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: 3000,
          divisions: 30,
          activeColor: VSPColors.accent,
          inactiveColor: VSPColors.divider,
          labels: RangeLabels(
            _priceRange.start.round().toString(),
            _priceRange.end.round().toString(),
          ),
          onChanged: (values) {
            setState(() {
              _priceRange = values;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRatingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Minimum Rating',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: VSPSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starPosition = index + 1;
            return IconButton(
              onPressed: () {
                setState(() {
                  _selectedRating = starPosition;
                });
              },
              icon: Icon(
                starPosition <= _selectedRating ? Icons.star : Icons.star_border,
                color: starPosition <= _selectedRating ? Colors.amber : VSPColors.textSecondary,
                size: 32,
              ),
            );
          }),
        ),
        const SizedBox(height: VSPSpacing.sm),
        Center(
          child: Text(
            _selectedRating == 0 ? 'Any Rating' : '$_selectedRating+ Stars',
            style: const TextStyle(color: VSPColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stadium Services',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: VSPSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _servicesFilters.entries.map((entry) {
            return FilterChip(
              label: Text(entry.key),
              selected: entry.value,
              onSelected: (selected) {
                setState(() {
                  _servicesFilters[entry.key] = selected;
                });
              },
              selectedColor: VSPColors.accent.withValues(alpha: 0.2),
              checkmarkColor: VSPColors.accent,
              labelStyle: TextStyle(
                color: entry.value ? VSPColors.accent : VSPColors.textPrimary,
                fontSize: 12,
              ),
              backgroundColor: VSPColors.surfaceAlt,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VSPRadius.sm),
                side: BorderSide(
                  color: entry.value ? VSPColors.accent : VSPColors.divider,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
