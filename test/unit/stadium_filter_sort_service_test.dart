import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/services/stadium_filter_sort_service.dart';

void main() {
  group('StadiumFilterSortService Unit Tests', () {
    final stadiumCairo = Stadium(
      id: 'std_cairo',
      name: 'Al Ahly Arena',
      location: 'Nasr City',
      governorate: 'Cairo',
      imageUrl: '',
      type: 'Football',
      size: '5 VS 5',
      baths: 1,
      cafeteria: 1,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 500.0,
      basePrice: 500.0,
      area: '800 m²',
      rating: 4.8,
      features: {'floorType': 'نجيل صناعي'},
    );

    final stadiumGiza = Stadium(
      id: 'std_giza',
      name: 'Zamalek Pitch',
      location: 'Mohandessin',
      governorate: 'Giza',
      imageUrl: '',
      type: 'Football',
      size: '7 VS 7',
      baths: 2,
      cafeteria: 1,
      playersPerTeam: 7,
      totalFieldCapacity: 14,
      pricePerHour: 300.0,
      basePrice: 300.0,
      area: '1200 m²',
      rating: 4.2,
      features: {'floorType': 'ترتان'},
    );

    final stadiumAlex = Stadium(
      id: 'std_alex',
      name: 'Alexandria Stadium',
      location: 'Smouha',
      governorate: 'Alexandria',
      imageUrl: '',
      type: 'Football',
      size: '5 VS 5',
      baths: 1,
      cafeteria: 0,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 400.0,
      basePrice: 400.0,
      area: '700 m²',
      rating: 4.9,
      features: {'floorType': 'نجيل طبيعي'},
    );

    final allStadiums = [stadiumCairo, stadiumGiza, stadiumAlex];

    test('Governorate filtering isolates stadium by governorate', () {
      final filtered = StadiumFilterSortService.filterAndSortStadiums(
        allStadiums: allStadiums,
        selectedGovernorate: 'Giza',
        selectedFloorType: 'All',
        searchQuery: '',
        sortOption: StadiumSortOption.featured,
      );

      expect(filtered.length, 1);
      expect(filtered.first.id, 'std_giza');
    });

    test('Floor type filtering isolates stadiums with requested floor material', () {
      final filtered = StadiumFilterSortService.filterAndSortStadiums(
        allStadiums: allStadiums,
        selectedGovernorate: 'All',
        selectedFloorType: 'ترتان',
        searchQuery: '',
        sortOption: StadiumSortOption.featured,
      );

      expect(filtered.length, 1);
      expect(filtered.first.id, 'std_giza');
    });

    test('Search query matches pitch name, location, and Arabic governorate', () {
      // Matches name
      final byName = StadiumFilterSortService.filterAndSortStadiums(
        allStadiums: allStadiums,
        selectedGovernorate: 'All',
        selectedFloorType: 'All',
        searchQuery: 'Ahly',
        sortOption: StadiumSortOption.featured,
      );
      expect(byName.length, 1);
      expect(byName.first.id, 'std_cairo');

      // Matches location
      final byLocation = StadiumFilterSortService.filterAndSortStadiums(
        allStadiums: allStadiums,
        selectedGovernorate: 'All',
        selectedFloorType: 'All',
        searchQuery: 'Smouha',
        sortOption: StadiumSortOption.featured,
      );
      expect(byLocation.length, 1);
      expect(byLocation.first.id, 'std_alex');

      // Matches Arabic governorate (القاهرة)
      final byArabicGov = StadiumFilterSortService.filterAndSortStadiums(
        allStadiums: allStadiums,
        selectedGovernorate: 'All',
        selectedFloorType: 'All',
        searchQuery: 'القاهرة',
        sortOption: StadiumSortOption.featured,
      );
      expect(byArabicGov.length, 1);
      expect(byArabicGov.first.id, 'std_cairo');
    });

    test('Sorting by priceLowToHigh sorts from lowest to highest pricePerHour', () {
      final sorted = StadiumFilterSortService.filterAndSortStadiums(
        allStadiums: allStadiums,
        selectedGovernorate: 'All',
        selectedFloorType: 'All',
        searchQuery: '',
        sortOption: StadiumSortOption.priceLowToHigh,
      );

      expect(sorted.map((s) => s.pricePerHour).toList(), [300.0, 400.0, 500.0]);
    });

    test('Sorting by topRated sorts from highest to lowest rating', () {
      final sorted = StadiumFilterSortService.filterAndSortStadiums(
        allStadiums: allStadiums,
        selectedGovernorate: 'All',
        selectedFloorType: 'All',
        searchQuery: '',
        sortOption: StadiumSortOption.topRated,
      );

      expect(sorted.map((s) => s.rating).toList(), [4.9, 4.8, 4.2]);
    });

    test('getSortLabel returns expected strings for both Arabic and English', () {
      expect(
        StadiumFilterSortService.getSortLabel(StadiumSortOption.priceLowToHigh, isArabic: true),
        'الأقل سعراً',
      );
      expect(
        StadiumFilterSortService.getSortLabel(StadiumSortOption.topRated, isArabic: false),
        'Top Rated',
      );
    });
  });
}
