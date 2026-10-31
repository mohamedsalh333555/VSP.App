import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
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
      _applyServerFilters(provider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Stadium> _filterAndSortStadiums(List<Stadium> allStadiums) => allStadiums;

  Map<String, dynamic> _serverFilterMap() => {
    'sports': <String>[],
    'location': _selectedGovernorate,
    'sizes': <String>[],
    'minPrice': 0.0,
    'maxPrice': 0.0,
    'noDepositOnly': false,
    'amenities': <String>[],
    'floorType': _selectedFloorType,
    'searchQuery': _searchQuery,
    'sortBy': _sortOption.name,
  };

  void _applyServerFilters(StadiumProvider provider, {bool isRefresh = true}) {
    if (isRefresh) {
      provider.applyFilters(_serverFilterMap());
    } else {
      provider.fetchStadiumsWithParams(
        isRefresh: false,
        governorate: _selectedGovernorate,
        floorType: _selectedFloorType,
        searchQuery: _searchQuery,
        sortBy: _sortOption.name,
      );
    }
  }

  // Refresh the current query without clearing the last authoritative page.
  void _refreshServerFilters(StadiumProvider provider) {
    provider.fetchStadiumsWithParams(
      isRefresh: true,
      governorate: _selectedGovernorate,
      floorType: _selectedFloorType,
      searchQuery: _searchQuery,
      sortBy: _sortOption.name,
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
    _applyServerFilters(context.read<StadiumProvider>());
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return VSPScaffold(
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
      body: SafeArea(top: false, bottom: true, child: Column(
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

                if (provider.errorMessage != null && provider.stadiums.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.info_circle_copy, color: VSPColors.warning, size: 42),
                          const SizedBox(height: 12),
                          Text(
                            isArabic ? 'تعذر تحميل الملاعب' : 'Could not load stadiums',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isArabic ? 'تحقق من اتصالك بالإنترنت ثم أعد المحاولة.' : 'Check your connection and try again.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () {
                              final filters = provider.currentFilters;
                              if (provider.isFilterActive && filters != null) {
                                _refreshServerFilters(provider);
                              } else {
                                _applyServerFilters(provider);
                              }
                            },
                            child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

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
                  onRefresh: () async => _refreshServerFilters(provider),
                  child: Column(
                    children: [
                      if (provider.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: VSPColors.warning.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              border: Border.all(color: VSPColors.warning.withValues(alpha: 0.30)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isArabic ? 'تعذر تحديث القائمة. نعرض آخر بيانات متاحة.' : 'Could not refresh the list. Showing the last available results.',
                                    style: const TextStyle(color: VSPColors.warning, fontSize: 11.5),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    final filters = provider.currentFilters;
                                    if (provider.isFilterActive && filters != null) {
                                      _refreshServerFilters(provider);
                                    } else {
                                      _refreshServerFilters(provider);
                                    }
                                  },
                                  child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                          itemCount: filteredStadiums.length + (provider.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= filteredStadiums.length) {
                              if (provider.errorMessage != null) {
                                return Center(
                                  child: TextButton(
                                    onPressed: () => _applyServerFilters(provider, isRefresh: false),
                                    child: Text(isArabic ? 'تعذر تحميل المزيد — إعادة المحاولة' : 'Could not load more — Retry'),
                                  ),
                                );
                              }
                              if (!provider.isLoadingMore && provider.hasMore) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && provider.errorMessage == null) {
                                    _applyServerFilters(provider, isRefresh: false);
                                  }
                                });
                              }
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator(color: VSPColors.accent)),
                              );
                            }
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
      )),
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
                onSubmitted: (_) => _applyServerFilters(context.read<StadiumProvider>()),
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
                  _applyServerFilters(context.read<StadiumProvider>());
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
        _applyServerFilters(context.read<StadiumProvider>());
      },
      onReset: _resetFilters,
    );
  }
}