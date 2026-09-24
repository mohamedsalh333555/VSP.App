import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/stadium_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/stadium_card.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../services/stadium_filter_sort_service.dart';
import '../widgets/all_stadiums/all_stadiums_filter_sheet.dart';
import 'stadium_details_screen.dart';

export '../services/stadium_filter_sort_service.dart' show StadiumSortOption;

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
    return StadiumFilterSortService.filterAndSortStadiums(
      allStadiums: allStadiums,
      selectedGovernorate: _selectedGovernorate,
      selectedFloorType: _selectedFloorType,
      searchQuery: _searchQuery,
      sortOption: _sortOption,
    );
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

          const SizedBox(height: 8),

          // 2. Stadiums List
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

  String _getSortLabel(bool isArabic) {
    return StadiumFilterSortService.getSortLabel(_sortOption, isArabic: isArabic);
  }

  void _showFilterBottomSheet(BuildContext context, bool isArabic) {
    AllStadiumsFilterSheet.show(
      context: context,
      initialSortOption: _sortOption,
      initialFloorType: _selectedFloorType,
      isArabic: isArabic,
      onApply: (sortOption, floorType) {
        setState(() {
          _sortOption = sortOption;
          _selectedFloorType = floorType;
        });
      },
      onReset: _resetFilters,
    );
  }
}