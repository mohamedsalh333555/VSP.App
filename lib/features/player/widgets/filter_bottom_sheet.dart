import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

import '../../../core/providers/stadium_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import 'filter/filter_amenities_panel.dart';
import 'filter/filter_category_sidebar.dart';
import 'filter/filter_location_panel.dart';
import 'filter/filter_price_panel.dart';
import 'filter/filter_specs_panel.dart';
import 'filter/filter_sports_panel.dart';

class FilterBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;
  const FilterBottomSheet({super.key, this.initialFilters});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String _selectedCategory = 'Sports';

  final Map<String, bool> _sportsFilters = {};
  bool _sportsInitialized = false;

  String? _selectedGov;

  final Map<String, bool> _sizeFilters = {
    '5 VS 5': false,
    '7 VS 7': false,
    '11 VS 11': false,
  };

  bool _noDepositOnly = false;

  late RangeValues _priceRange;
  bool _priceInitialized = false;

  final Map<String, bool> _amenitiesFilters = {
    'دش وحمام': false,
    'غرف تغيير ملابس': false,
    'كافتيريا ومشروبات': false,
    'جراج سيارات': false,
    'كشافات إضاءة ليلاً': false,
    'كرة': false,
    'مقاعد': false,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stadiumProvider = context.watch<StadiumProvider>();

    if (!_sportsInitialized) {
      final availableSports = stadiumProvider.availableSportTypes;
      final List<dynamic> initSports = widget.initialFilters?['sports'] is List
          ? widget.initialFilters!['sports'] as List
          : [];
      for (final sport in availableSports) {
        _sportsFilters[sport] = initSports.contains(sport);
      }
      _sportsInitialized = true;
    }

    if (!_priceInitialized) {
      final maxPriceFromDb = stadiumProvider.maxStadiumPrice;
      final double startPrice = (widget.initialFilters?['minPrice'] as num?)?.toDouble() ?? 0.0;
      final double endPrice = (widget.initialFilters?['maxPrice'] as num?)?.toDouble() ?? maxPriceFromDb;
      _priceRange = RangeValues(
        startPrice.clamp(0.0, maxPriceFromDb),
        endPrice.clamp(0.0, maxPriceFromDb),
      );
      _priceInitialized = true;
    }

    if (widget.initialFilters != null) {
      if (_selectedGov == null && widget.initialFilters!['location'] is String) {
        _selectedGov = widget.initialFilters!['location'] as String?;
      }
      if (widget.initialFilters!['noDepositOnly'] is bool) {
        _noDepositOnly = widget.initialFilters!['noDepositOnly'] as bool;
      }
      if (widget.initialFilters!['sizes'] is List) {
        final List<dynamic> initSizes = widget.initialFilters!['sizes'] as List;
        for (final key in _sizeFilters.keys) {
          if (initSizes.contains(key)) _sizeFilters[key] = true;
        }
      }
      if (widget.initialFilters!['amenities'] is List) {
        final List<dynamic> initAmenities = widget.initialFilters!['amenities'] as List;
        for (final key in _amenitiesFilters.keys) {
          if (initAmenities.contains(key)) _amenitiesFilters[key] = true;
        }
      }
    }
  }

  int getCategoryBadgeCount(String categoryKey) {
    final maxDb = context.read<StadiumProvider>().maxStadiumPrice;
    switch (categoryKey) {
      case 'Sports':
        return _sportsFilters.values.where((v) => v).length;
      case 'Location':
        return _selectedGov != null ? 1 : 0;
      case 'Pitch Specs':
        return _sizeFilters.values.where((v) => v).length;
      case 'Price & Deposit':
        int c = _noDepositOnly ? 1 : 0;
        if (_priceRange.start > 0 || _priceRange.end < maxDb) c++;
        return c;
      case 'Amenities':
        return _amenitiesFilters.values.where((v) => v).length;
      default:
        return 0;
    }
  }

  int get _activeFiltersCount {
    int count = 0;
    count += _sportsFilters.values.where((v) => v).length;
    count += _sizeFilters.values.where((v) => v).length;
    count += _amenitiesFilters.values.where((v) => v).length;
    if (_selectedGov != null) count++;
    if (_noDepositOnly) count++;
    final maxDb = context.read<StadiumProvider>().maxStadiumPrice;
    if (_priceRange.start > 0 || _priceRange.end < maxDb) count++;
    return count;
  }

  void _resetAll() {
    final maxDb = context.read<StadiumProvider>().maxStadiumPrice;
    setState(() {
      _sportsFilters.updateAll((key, value) => false);
      _sizeFilters.updateAll((key, value) => false);
      _amenitiesFilters.updateAll((key, value) => false);
      _selectedGov = null;
      _noDepositOnly = false;
      _priceRange = RangeValues(0, maxDb);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final maxDbPrice = context.watch<StadiumProvider>().maxStadiumPrice;
    final activeCount = _activeFiltersCount;

    final Map<String, String> categoryTitles = {
      'Sports': isArabic ? 'نوع الرياضة' : 'Sport',
      'Location': isArabic ? 'الموقع' : 'Location',
      'Pitch Specs': isArabic ? 'سعة الملعب' : 'Pitch Capacity',
      'Price & Deposit': isArabic ? 'السعر والحجز' : 'Price & Booking',
      'Amenities': isArabic ? 'المرافق والخدمات' : 'Amenities',
    };

    final Map<String, IconData> categoryIcons = {
      'Sports': Iconsax.cup_copy,
      'Location': Iconsax.location_copy,
      'Pitch Specs': Iconsax.maximize_copy,
      'Price & Deposit': Iconsax.wallet_1_copy,
      'Amenities': Iconsax.magic_star_copy,
    };

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 1. Header & Handle Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: VSPColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          isArabic ? 'تصفية الملاعب' : 'Filter Stadiums',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (activeCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: VSPColors.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$activeCount',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Iconsax.close_circle_copy,
                        color: VSPColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: VSPColors.divider, height: 1),

          // ── 2. Flexible Content (Side Tabs + Dynamic Panel) ──
          Flexible(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilterCategorySidebar(
                    selectedCategory: _selectedCategory,
                    isArabic: isArabic,
                    categoryTitles: categoryTitles,
                    categoryIcons: categoryIcons,
                    getBadgeCount: getCategoryBadgeCount,
                    onSelectCategory: (cat) => setState(() => _selectedCategory = cat),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildCategoryContent(isArabic, l10n, maxDbPrice),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Fixed Bottom Action Buttons ──
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              bottomPadding > 0 ? bottomPadding + 8 : 16,
            ),
            decoration: const BoxDecoration(
              color: VSPColors.surface,
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
                  flex: 1,
                  child: PrimaryButton(
                    text: l10n.reset,
                    height: 46,
                    onPressed: _resetAll,
                    color: VSPColors.surfaceAlt,
                    textColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    text: activeCount > 0
                        ? (isArabic ? 'تطبيق ($activeCount)' : 'Apply ($activeCount)')
                        : l10n.apply,
                    height: 46,
                    onPressed: () {
                      final filters = {
                        'sports': _sportsFilters.entries.where((e) => e.value).map((e) => e.key).toList(),
                        'location': _selectedGov,
                        'sizes': _sizeFilters.entries.where((e) => e.value).map((e) => e.key).toList(),
                        'noDepositOnly': _noDepositOnly,
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
    );
  }

  Widget _buildCategoryContent(bool isArabic, AppLocalizations l10n, double maxDbPrice) {
    switch (_selectedCategory) {
      case 'Sports':
        return FilterSportsPanel(
          sportsFilters: _sportsFilters,
          isArabic: isArabic,
          onToggleSport: (key, selected) => setState(() => _sportsFilters[key] = selected),
        );
      case 'Location':
        return FilterLocationPanel(
          selectedGov: _selectedGov,
          isArabic: isArabic,
          onSelectGov: (val) => setState(() => _selectedGov = val),
        );
      case 'Pitch Specs':
        return FilterSpecsPanel(
          sizeFilters: _sizeFilters,
          isArabic: isArabic,
          onToggleSize: (key, val) => setState(() => _sizeFilters[key] = val),
        );
      case 'Price & Deposit':
        return FilterPricePanel(
          priceRange: _priceRange,
          noDepositOnly: _noDepositOnly,
          maxDbPrice: maxDbPrice,
          isArabic: isArabic,
          currency: l10n.egCurrency,
          onPriceChanged: (vals) => setState(() => _priceRange = vals),
          onNoDepositChanged: (val) => setState(() => _noDepositOnly = val),
        );
      case 'Amenities':
        return FilterAmenitiesPanel(
          amenitiesFilters: _amenitiesFilters,
          isArabic: isArabic,
          onToggleAmenity: (key, val) => setState(() => _amenitiesFilters[key] = val),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
