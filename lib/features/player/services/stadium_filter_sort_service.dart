import '../../../core/constants/egypt_governorates.dart';
import '../../../data/models.dart';

/// Available sorting modes for pitch listings.
enum StadiumSortOption {
  featured,
  priceLowToHigh,
  priceHighToLow,
  topRated,
}

/// Pure business service providing search, governorate normalization,
/// floor-type filtering, and sorting for stadium listings.
class StadiumFilterSortService {
  const StadiumFilterSortService._();

  /// Filters a list of stadiums according to governorate, pitch floor type,
  /// and search keywords (stadium name, city/location, or governorate in AR/EN),
  /// then sorts the resulting subset according to the given [sortOption].
  static List<Stadium> filterAndSortStadiums({
    required List<Stadium> allStadiums,
    required String selectedGovernorate,
    required String selectedFloorType,
    required String searchQuery,
    required StadiumSortOption sortOption,
  }) {
    var list = allStadiums.where((stadium) {
      // 1. Governorate Filter
      if (selectedGovernorate != 'All') {
        final rawGov = stadium.governorate ?? '';
        final stdGov = (EgyptGovernorates.resolveGoogleName(rawGov) ?? rawGov).toLowerCase();
        final selectedStd = (EgyptGovernorates.resolveGoogleName(selectedGovernorate) ?? selectedGovernorate).toLowerCase();
        if (stdGov != selectedStd) {
          return false;
        }
      }

      // 2. Floor Type Filter
      if (selectedFloorType != 'All') {
        final features = stadium.features;
        final floorType = (features is Map ? features['floorType']?.toString() : '') ?? '';
        if (!floorType.toLowerCase().contains(selectedFloorType.toLowerCase())) {
          return false;
        }
      }

      // 3. Search Query (Name, Location, Governorate)
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
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
    switch (sortOption) {
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
        // Default ranking / original order
        break;
    }

    return list;
  }

  /// Returns localized label for the current sorting choice.
  static String getSortLabel(StadiumSortOption sortOption, {required bool isArabic}) {
    switch (sortOption) {
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
}
