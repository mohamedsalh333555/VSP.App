import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/egypt_governorates.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/stadium_card.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import 'stadium_details_screen.dart';

enum StadiumSortOption {
  featured,
  priceLowToHigh,
  priceHighToLow,
  topRated,
}

class AllStadiumsScreen extends StatefulWidget {
  final String? initialGovernorate;
  final String? initialSearchQuery;

  const AllStadiumsScreen({
    super.key,
    this.initialGovernorate,
    this.initialSearchQuery,
  });

  @override
  State<AllStadiumsScreen> createState() => _AllStadiumsScreenState();
}

class _AllStadiumsScreenState extends State<AllStadiumsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedGovernorate = 'All';
  String _selectedFloorType = 'All';
  StadiumSortOption _sortOption = StadiumSortOption.featured;

  final List<String> _governorates = [
    'All',
    'Cairo',
    'Giza',
    'Alexandria',
    'Qalyubia',
    'Dakahlia',
    'Sharqia',
    'Gharbia',
    'Monufia',
    'Beheira',
    'Kafr El Sheikh',
    'Damietta',
    'Port Said',
    'Ismailia',
    'Suez',
    'North Sinai',
    'South Sinai',
    'Beni Suef',
    'Faiyum',
    'Minya',
    'Asyut',
    'Sohag',
    'Qena',
    'Luxor',
    'Aswan',
    'Red Sea',
    'New Valley',
    'Matrouh',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialGovernorate != null && widget.initialGovernorate!.isNotEmpty) {
      _selectedGovernorate = widget.initialGovernorate!;
    }
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
      _searchQuery = widget.initialSearchQuery!;
    }

    // Refresh stadiums on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<StadiumProvider>(context, listen: false);
      provider.fetchStadiums(isRefresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Stadium> _filterAndSortStadiums(List<Stadium> allStadiums) {
    var list = allStadiums.where((stadium) {
      // 1. Governorate Filter
      if (_selectedGovernorate != 'All') {
        final rawGov = stadium.governorate ?? '';
        final stdGov = (EgyptGovernorates.resolveGoogleName(rawGov) ?? rawGov).toLowerCase();
        final selectedStd = (EgyptGovernorates.resolveGoogleName(_selectedGovernorate) ?? _selectedGovernorate).toLowerCase();
        if (stdGov != selectedStd) {
          return false;
        }
      }

      // 2. Floor Type Filter
      if (_selectedFloorType != 'All') {
        final features = stadium.features;
        final floorType = (features is Map ? features['floorType']?.toString() : '') ?? '';
        if (!floorType.toLowerCase().contains(_selectedFloorType.toLowerCase())) {
          return false;
        }
      }

      // 3. Search Query (Name, Location, Governorate)
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final name = stadium.name.toLowerCase();
        final loc = stadium.location.toLowerCase();
        final gov = (stadium.governorate ?? '').toLowerCase();
        final arabicGov = (EgyptGovernorates.governorateToArabic[stadium.governorate ?? ''] ?? '').toLowerCase();

        if (!name.contains(q) && !loc.contains(q) && !gov.contains(q) && !arabicGov.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();

    // 4. Sorting
    switch (_sortOption) {
      case StadiumSortOption.priceLowToHigh:
        list.sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));
        break;
      case StadiumSortOption.priceHighToLow:
        list.sort((a, b) => b.pricePerHour.compareTo(a.pricePerHour));
        break;
      case StadiumSortOption.topRated:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case StadiumSortOption.featured:
        // Default ranking
        break;
    }

    return list;
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedGovernorate = 'All';
      _selectedFloorType = 'All';
      _sortOption = StadiumSortOption.featured;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.surface,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          isArabic ? 'جميع الملاعب' : 'All Stadiums',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.filter_search_copy, color: VSPColors.accent, size: 22),
            onPressed: () => _showFilterBottomSheet(context, isArabic),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar & Quick Filters
          _buildSearchHeader(context, isArabic),

          // 2. Governorate Filter Chips
          _buildGovernorateFilterRow(context, isArabic),

          const SizedBox(height: 8),

          // 3. Stadiums List
          Expanded(
            child: Consumer<StadiumProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.stadiums.isEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: 4,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: CardSkeleton(),
                    ),
                  );
                }

                final filteredStadiums = _filterAndSortStadiums(provider.stadiums);

                if (filteredStadiums.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            VSPEmptyState(
                              icon: Iconsax.building_3_copy,
                              title: isArabic ? 'لم يتم العثور على ملاعب' : 'No Stadiums Found',
                              subtitle: isArabic
                                  ? 'لا توجد ملاعب تطابق معايير البحث أو الفلترة المحددة.'
                                  : 'No stadiums match your current search and filter criteria.',
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _resetFilters,
                              icon: const Icon(Iconsax.refresh_copy, size: 18),
                              label: Text(isArabic ? 'إعادة ضبط الفلاتر' : 'Reset Filters'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: VSPColors.accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: VSPColors.accent,
                  backgroundColor: VSPColors.surface,
                  onRefresh: () => provider.fetchStadiums(isRefresh: true),
                  child: Column(
                    children: [
                      // Results Counter
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isArabic
                                  ? 'تم العثور على ${filteredStadiums.length} ملعب'
                                  : '${filteredStadiums.length} stadiums found',
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            GestureDetector(
                              onTap: () => _showFilterBottomSheet(context, isArabic),
                              child: Row(
                                children: [
                                  const Icon(Iconsax.sort_copy, color: VSPColors.accent, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getSortLabel(isArabic),
                                    style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // List of Stadiums
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filteredStadiums.length,
                          itemBuilder: (context, index) {
                            final stadium = filteredStadiums[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: StadiumCard(
                                stadium: stadium,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StadiumDetailsScreen(stadium: stadium),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context, bool isArabic) {
    return Container(
      color: VSPColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(color: VSPColors.divider, width: 0.8),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Iconsax.search_normal_1_copy, color: VSPColors.textSecondary, size: 20),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: isArabic ? 'ابحث باسم الملعب، المدينة أو المحافظة...' : 'Search stadium name or city...',
                  hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 18),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGovernorateFilterRow(BuildContext context, bool isArabic) {
    return Container(
      height: 44,
      color: VSPColors.surface.withValues(alpha: 0.7),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _governorates.length,
        itemBuilder: (context, index) {
          final gov = _governorates[index];
          final isSelected = _selectedGovernorate.toLowerCase() == gov.toLowerCase();
          final arabicLabel = gov == 'All'
              ? (isArabic ? 'الكل' : 'All')
              : (EgyptGovernorates.governorateToArabic[gov] ?? gov);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                isArabic ? arabicLabel : gov,
                style: TextStyle(
                  color: isSelected ? Colors.black : VSPColors.textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              selectedColor: VSPColors.accent,
              backgroundColor: VSPColors.surfaceAlt,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? VSPColors.accent : VSPColors.divider,
                  width: 0.8,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedGovernorate = gov;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  String _getSortLabel(bool isArabic) {
    switch (_sortOption) {
      case StadiumSortOption.featured:
        return isArabic ? 'المميزة' : 'Featured';
      case StadiumSortOption.priceLowToHigh:
        return isArabic ? 'الأقل سعراً' : 'Price: Low';
      case StadiumSortOption.priceHighToLow:
        return isArabic ? 'الأعلى سعراً' : 'Price: High';
      case StadiumSortOption.topRated:
        return isArabic ? 'الأعلى تقييماً' : 'Top Rated';
    }
  }

  void _showFilterBottomSheet(BuildContext context, bool isArabic) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VSPColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic ? 'تصفية وترتيب الملاعب' : 'Filter & Sort Stadiums',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          _resetFilters();
                          Navigator.pop(ctx);
                        },
                        child: Text(isArabic ? 'إعادة ضبط' : 'Reset', style: const TextStyle(color: VSPColors.accent)),
                      ),
                    ],
                  ),
                  const Divider(color: VSPColors.divider),
                  const SizedBox(height: 12),

                  // Sort Options
                  Text(
                    isArabic ? 'ترتيب حسب:' : 'Sort By:',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSortChip(StadiumSortOption.featured, isArabic ? 'المميزة' : 'Featured', setModalState),
                      _buildSortChip(StadiumSortOption.topRated, isArabic ? 'الأعلى تقييماً ⭐' : 'Top Rated ⭐', setModalState),
                      _buildSortChip(StadiumSortOption.priceLowToHigh, isArabic ? 'الأقل سعراً 💵' : 'Lowest Price 💵', setModalState),
                      _buildSortChip(StadiumSortOption.priceHighToLow, isArabic ? 'الأعلى سعراً' : 'Highest Price', setModalState),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Floor Type Options
                  Text(
                    isArabic ? 'نوع الأرضية:' : 'Pitch / Floor Type:',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFloorChip('All', isArabic ? 'الكل' : 'All', setModalState),
                      _buildFloorChip('نجيل صناعي', isArabic ? 'نجيل صناعي' : 'Artificial Grass', setModalState),
                      _buildFloorChip('نجيل طبيعي', isArabic ? 'نجيل طبيعي' : 'Natural Grass', setModalState),
                      _buildFloorChip('ترتان', isArabic ? 'ترتان' : 'Tartan', setModalState),
                      _buildFloorChip('صالة', isArabic ? 'صالة مغطاة' : 'Indoor Court', setModalState),
                    ],
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VSPColors.accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                      ),
                      child: Text(
                        isArabic ? 'تطبيق الفلترة' : 'Apply Filters',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortChip(StadiumSortOption option, String label, StateSetter setModalState) {
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
          setModalState(() => _sortOption = option);
          setState(() => _sortOption = option);
        }
      },
    );
  }

  Widget _buildFloorChip(String floorType, String label, StateSetter setModalState) {
    final isSelected = _selectedFloorType.toLowerCase() == floorType.toLowerCase();
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
          setModalState(() => _selectedFloorType = floorType);
          setState(() => _selectedFloorType = floorType);
        }
      },
    );
  }
}