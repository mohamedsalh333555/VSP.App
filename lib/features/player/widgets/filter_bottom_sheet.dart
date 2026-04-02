import 'package:flutter/material.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String _selectedCategory = 'Sports';
  
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
    final l10n = AppLocalizations.of(context)!;
    
    // Initialize or Update Category Titles based on Localization
    final sportsTitle = l10n.sports;
    final priceTitle = l10n.priceRange;
    final ratingsTitle = l10n.ratings;
    final servicesTitle = l10n.services;

    // Mapping internal keys to localized titles for UI
    final Map<String, String> categoryTitles = {
      'Sports': sportsTitle,
      'Price Range': priceTitle,
      'Ratings': ratingsTitle,
      'Services': servicesTitle,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: VSPColors.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(VSPRadius.xl),
            topRight: Radius.circular(VSPRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    l10n.filters,
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
                        _buildCategoryItem('Sports', categoryTitles['Sports']!, Icons.sports_soccer),
                        _buildCategoryItem('Price Range', categoryTitles['Price Range']!, Icons.attach_money),
                        _buildCategoryItem('Ratings', categoryTitles['Ratings']!, Icons.star_outline),
                        _buildCategoryItem('Services', categoryTitles['Services']!, Icons.room_service),
                      ],
                    ),
                  ),

                  // Right Content Area
                  Expanded(
                    child: Container(
                       padding: const EdgeInsets.all(VSPSpacing.md),
                      child: _buildContentForCategory(l10n),
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
                      text: l10n.reset,
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
                      text: l10n.apply,
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
      ),
    );
  }

  Widget _buildCategoryItem(String key, String title, IconData icon) {
    final isSelected = _selectedCategory == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = key;
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

  Widget _buildContentForCategory(AppLocalizations l10n) {
    switch (_selectedCategory) {
      case 'Sports':
        return _buildSportsContent(l10n);
      case 'Price Range':
        return _buildPriceRangeContent(l10n);
      case 'Ratings':
        return _buildRatingsContent(l10n);
      case 'Services':
        return _buildServicesContent(l10n);
      default:
        return const SizedBox();
    }
  }

  Widget _buildSportsContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectSports,
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

  Widget _buildPriceRangeContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.priceRange} (${l10n.egCurrency})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: VSPSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_priceRange.start.round()} ${l10n.egCurrency}', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
            Text('${_priceRange.end.round()} ${l10n.egCurrency}', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
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

  Widget _buildRatingsContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.minRating,
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
            _selectedRating == 0 ? l10n.anyRating : '$_selectedRating+ ${l10n.stars}',
            style: const TextStyle(color: VSPColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.stadiumServices,
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
