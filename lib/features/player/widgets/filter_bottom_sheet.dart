import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/constants/egypt_governorates.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String _selectedCategory = 'Sports';

  final Map<String, bool> _sportsFilters = {
    'Football': false,
    'Basketball': false,
    'Padel': false,
    'Volleyball': false,
    'Handball': false,
  };

  String? _selectedGov;

  final Map<String, bool> _sizeFilters = {
    '5 VS 5': false,
    '7 VS 7': false,
    '11 VS 11': false,
  };

  RangeValues _priceRange = const RangeValues(0, 3000);

  final Map<String, bool> _amenitiesFilters = {
    'Professional Lighting': false,
    'Spectator Seats': false,
    'Ball Provided': false,
    'Cafeteria': false,
    'Changing Rooms': false,
    'Garage': false,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final Map<String, String> categoryTitles = {
      'Sports': isArabic ? 'الرياضة' : 'Sports',
      'Location': isArabic ? 'الموقع' : 'Location',
      'Pitch Size': isArabic ? 'مساحة الملعب' : 'Pitch Size',
      'Price Range': isArabic ? 'نطاق السعر' : 'Price Range',
      'Amenities': isArabic ? 'الخدمات والمرافق' : 'Amenities',
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
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
                    l10n.filters,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      LucideIcons.x,
                      color: VSPColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Content - Split View
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Sidebar - Categories (Scrollable)
                  Container(
                    width: 115,
                    decoration: const BoxDecoration(
                      color: VSPColors.surface,
                      border: Border(
                        right: BorderSide(
                          color: VSPColors.divider,
                          width: 1,
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildCategoryItem('Sports', categoryTitles['Sports']!, LucideIcons.trophy),
                          _buildCategoryItem('Location', categoryTitles['Location']!, LucideIcons.mapPin),
                          _buildCategoryItem('Pitch Size', categoryTitles['Pitch Size']!, LucideIcons.maximize),
                          _buildCategoryItem('Price Range', categoryTitles['Price Range']!, LucideIcons.dollarSign),
                          _buildCategoryItem('Amenities', categoryTitles['Amenities']!, LucideIcons.sparkles),
                        ],
                      ),
                    ),
                  ),

                  // Right Content Area (Scrollable to prevent overflow)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(VSPSpacing.md),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildContentForCategory(isArabic, l10n),
                      ),
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
                          _sizeFilters.updateAll((key, value) => false);
                          _amenitiesFilters.updateAll((key, value) => false);
                          _selectedGov = null;
                          _priceRange = const RangeValues(0, 3000);
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
                          'sports': _sportsFilters.entries.where((e) => e.value).map((e) => e.key).toList(),
                          'location': _selectedGov,
                          'sizes': _sizeFilters.entries.where((e) => e.value).map((e) => e.key).toList(),
                          'minPrice': _priceRange.start,
                          'maxPrice': _priceRange.end,
                          'amenities': _amenitiesFilters.entries.where((e) => e.value).map((e) => e.key).toList(),
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

  Widget _buildContentForCategory(bool isArabic, AppLocalizations l10n) {
    switch (_selectedCategory) {
      case 'Sports':
        return _buildSportsContent(isArabic, l10n);
      case 'Location':
        return _buildLocationContent(isArabic, l10n);
      case 'Pitch Size':
        return _buildPitchSizeContent(isArabic, l10n);
      case 'Price Range':
        return _buildPriceRangeContent(isArabic, l10n);
      case 'Amenities':
        return _buildAmenitiesContent(isArabic, l10n);
      default:
        return const SizedBox();
    }
  }

  String _localizeSport(String key, bool isArabic) {
    if (!isArabic) return key;
    switch (key) {
      case 'Football': return 'كرة القدم';
      case 'Basketball': return 'كرة السلة';
      case 'Padel': return 'بادل';
      case 'Volleyball': return 'الكرة الطائرة';
      case 'Handball': return 'كرة اليد';
      default: return key;
    }
  }

  String _localizeSize(String key, bool isArabic) {
    if (!isArabic) return key;
    switch (key) {
      case '5 VS 5': return '5 ضد 5';
      case '7 VS 7': return '7 ضد 7';
      case '11 VS 11': return '11 ضد 11';
      default: return key;
    }
  }

  String _localizeAmenity(String key, bool isArabic) {
    if (!isArabic) return key;
    switch (key) {
      case 'Professional Lighting': return 'إضاءة احترافية';
      case 'Spectator Seats': return 'مدرجات الجمهور';
      case 'Ball Provided': return 'كرة متوفرة';
      case 'Cafeteria': return 'كافتيريا';
      case 'Changing Rooms': return 'غرف تغيير ملابس';
      case 'Garage': return 'جراج سيارات';
      default: return key;
    }
  }

  Widget _buildSportsContent(bool isArabic, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'اختر الرياضات' : 'Select Sports',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: VSPSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _sportsFilters.entries.map((entry) {
            final isSelected = entry.value;
            return ChoiceChip(
              label: Text(_localizeSport(entry.key, isArabic)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _sportsFilters[entry.key] = selected;
                });
              },
              selectedColor: VSPColors.accent.withValues(alpha: 0.15),
              checkmarkColor: VSPColors.accent,
              labelStyle: TextStyle(
                color: isSelected ? VSPColors.accent : VSPColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              backgroundColor: VSPColors.surface,
              shape: const StadiumBorder(),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationContent(bool isArabic, AppLocalizations l10n) {
    final govs = EgyptGovernorates.allGovernorates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'اختر المحافظة' : 'Select Governorate',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: VSPSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGov,
              hint: Text(
                isArabic ? 'كل المحافظات' : 'All Governorates',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14),
              ),
              dropdownColor: VSPColors.surface,
              icon: Icon(LucideIcons.chevronDown, color: VSPColors.textSecondary),
              isExpanded: true,
              style: Theme.of(context).textTheme.bodyMedium,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedGov = newValue;
                });
              },
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(isArabic ? 'كل المحافظات' : 'All Governorates'),
                ),
                ...govs.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPitchSizeContent(bool isArabic, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'حجم الملعب' : 'Pitch Size',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: VSPSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _sizeFilters.entries.map((entry) {
            final isSelected = entry.value;
            return ChoiceChip(
              label: Text(_localizeSize(entry.key, isArabic)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _sizeFilters[entry.key] = selected;
                });
              },
              selectedColor: VSPColors.accent.withValues(alpha: 0.15),
              checkmarkColor: VSPColors.accent,
              labelStyle: TextStyle(
                color: isSelected ? VSPColors.accent : VSPColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              backgroundColor: VSPColors.surface,
              shape: const StadiumBorder(),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriceRangeContent(bool isArabic, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.priceRange} (${l10n.egCurrency})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
          inactiveColor: VSPColors.surfaceAlt,
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

  Widget _buildAmenitiesContent(bool isArabic, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'الخدمات والمرافق' : 'Amenities',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: VSPSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _amenitiesFilters.entries.map((entry) {
            final isSelected = entry.value;
            return FilterChip(
              label: Text(_localizeAmenity(entry.key, isArabic)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _amenitiesFilters[entry.key] = selected;
                });
              },
              selectedColor: VSPColors.accent.withValues(alpha: 0.15),
              checkmarkColor: VSPColors.accent,
              labelStyle: TextStyle(
                color: isSelected ? VSPColors.accent : VSPColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              backgroundColor: VSPColors.surface,
              shape: const StadiumBorder(),
            );
          }).toList(),
        ),
      ],
    );
  }
}
