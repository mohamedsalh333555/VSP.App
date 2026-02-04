import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

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
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.textSecondary.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: AppTheme.textSecondary,
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
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground.withOpacity(0.3),
                    border: Border(
                      right: BorderSide(
                        color: AppTheme.textSecondary.withOpacity(0.1),
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
                    padding: const EdgeInsets.all(20),
                    child: _buildContentForCategory(),
                  ),
                ),
              ],
            ),
          ),

          // Footer Buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppTheme.textSecondary.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Reset Button
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _sportsFilters.updateAll((key, value) => false);
                      });
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Apply Button
                Expanded(
                  child: InkWell(
                    onTap: () {
                      // Apply filters and close
                      Navigator.pop(context, _sportsFilters);
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.neonGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          color: AppTheme.darkBackground,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.neonGreen.withOpacity(0.1) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppTheme.neonGreen : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.neonGreen : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppTheme.neonGreen : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        const Text(
          'Select Sports',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        ..._sportsFilters.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
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
                      color: entry.value ? AppTheme.neonGreen : Colors.transparent,
                      border: Border.all(
                        color: entry.value ? AppTheme.neonGreen : AppTheme.textSecondary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: entry.value
                        ? const Icon(
                            Icons.check,
                            color: AppTheme.darkBackground,
                            size: 16,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildPriceRangeContent() {
    return const Center(
      child: Text(
        'Price Range filters coming soon',
        style: TextStyle(
          color: AppTheme.textSecondary,
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
          color: AppTheme.textSecondary,
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
          color: AppTheme.textSecondary,
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
          color: AppTheme.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}
