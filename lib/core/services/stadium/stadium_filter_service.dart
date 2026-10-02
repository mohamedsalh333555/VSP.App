import '../../../data/models.dart';
import '../../utils/geo_helper.dart';

/// Pure stateless filtering and sorting service for Stadium listings.
class StadiumFilterService {
  const StadiumFilterService._();

  /// Determines if a stadium operates on a late night shift.
  static bool isNightShiftStadium(Stadium stadium) {
    final closing = stadium.closingTime.toLowerCase();
    if (closing.contains('am') ||
        closing.contains('صباحاً') ||
        closing.contains('00:') ||
        closing.contains('01:') ||
        closing.contains('02:') ||
        closing.contains('03:') ||
        closing.contains('04:') ||
        closing.contains('05:') ||
        closing.contains('24')) {
      return true;
    }
    final features = stadium.features;
    if (features is Map && features['workingHours'] is Map) {
      final end = features['workingHours']['end']?.toString().toLowerCase() ?? '';
      if (end.contains('am') ||
          end.contains('صباحاً') ||
          end.contains('01:') ||
          end.contains('02:') ||
          end.contains('03:') ||
          end.contains('04:')) {
        return true;
      }
    }
    return false;
  }

  /// Evaluates whether [stadium] provides a specific amenity or facility feature.
  static bool checkAmenity(Stadium stadium, String amenity) {
    final dynamic feats = stadium.features;
    final Map<dynamic, dynamic> featMap = feats is Map ? feats : {};

    final normalizedAmenity = amenity.trim().toLowerCase();

    // 1. Payment & Deposit
    if (normalizedAmenity == 'no deposit needed' || amenity.trim() == 'حجز بدون عربون (دفع نقدي)') {
      return !stadium.needsDeposit;
    }

    // 2. Real Owner Amenities (Strictly matching owner inputs)
    if (normalizedAmenity == 'showers & baths' || amenity.trim() == 'دش وحمام') {
      return featMap['bathOption'] == 'Yes' || featMap['hasShower'] == true || featMap['shower'] == true;
    }
    if (normalizedAmenity == 'changing rooms' || amenity.trim() == 'غرف تغيير ملابس') {
      return featMap['changingRoom'] == true || featMap['changingRooms'] == true || featMap['hasChangingRooms'] == true;
    }
    if (normalizedAmenity == 'night floodlights' || amenity.trim() == 'كشافات ليلية') {
      // Late operating hours are the canonical signal when the owner does not
      // explicitly persist a separate floodlight flag.
      return isNightShiftStadium(stadium) ||
          featMap['nightFloodlights'] == true ||
          featMap['floodlights'] == true ||
          featMap['hasFloodlights'] == true;
    }
    if (normalizedAmenity == 'cafeteria & drinks' || amenity.trim() == 'كافتيريا ومشروبات') {
      return stadium.cafeteria > 0 || featMap['cafeteria'] == true || featMap['hasCafeteria'] == true;
    }
    if (normalizedAmenity == 'spectator seats' || amenity.trim() == 'مدرجات جمهور' || amenity.trim() == 'مقاعد') {
      final rawSeats = featMap['seats'];
      final seatCount = rawSeats is num ? rawSeats.toInt() : int.tryParse(rawSeats?.toString() ?? '') ?? 0;
      return seatCount > 0 || featMap['hasSeats'] == true || stadium.hasSeats;
    }
    if (normalizedAmenity == 'garage & parking' || amenity.trim() == 'جراج سيارات') {
      return featMap['garage'] == true || featMap['hasGarage'] == true || featMap['parking'] == true;
    }

    // Fallback checks
    final key = amenity.replaceAll(' ', '').toLowerCase();
    return featMap[key] == true || featMap['has${amenity.replaceAll(' ', '')}'] == true;
  }

  /// Filters stadiums by query matching name or location.
  static List<Stadium> searchStadiums(List<Stadium> stadiums, String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return stadiums;

    return stadiums.where((stadium) =>
        stadium.name.toLowerCase().contains(cleanQuery) ||
        stadium.location.toLowerCase().contains(cleanQuery)
    ).toList();
  }

  /// Filters stadiums by location keyword.
  static List<Stadium> filterByLocation(List<Stadium> stadiums, String location) {
    final query = location.trim().toLowerCase();
    if (query.isEmpty) return stadiums;

    return stadiums.where((stadium) =>
        stadium.location.toLowerCase().contains(query)
    ).toList();
  }

  /// Filters stadiums by price range.
  static List<Stadium> filterByPriceRange(List<Stadium> stadiums, double minPrice, double maxPrice) {
    return stadiums.where((stadium) =>
        stadium.pricePerHour >= minPrice && stadium.pricePerHour <= maxPrice
    ).toList();
  }

  /// Applies active quick filter chips ('night_shift' or 'no_deposit').
  static List<Stadium> applyQuickFilter(List<Stadium> stadiums, String? quickFilter) {
    if (quickFilter == 'night_shift') {
      return stadiums.where((s) => isNightShiftStadium(s)).toList();
    } else if (quickFilter == 'no_deposit') {
      return stadiums.where((s) => !s.needsDeposit || s.depositAmount <= 0).toList();
    }
    return stadiums;
  }

  /// Sorts stadiums in-place by distance from user coordinates.
  static void sortStadiumsByDistance(List<Stadium> stadiums, double userLat, double userLng) {
    stadiums.sort((a, b) {
      if (a.lat == null || a.lng == null) return 1;
      if (b.lat == null || b.lng == null) return -1;

      final distA = GeoHelper.calculateDistance(userLat, userLng, a.lat!, a.lng!);
      final distB = GeoHelper.calculateDistance(userLat, userLng, b.lat!, b.lng!);

      return distA.compareTo(distB);
    });
  }

  /// Extracts unique sport types present in the stadium catalog.
  static List<String> getAvailableSportTypes(List<Stadium> stadiums, List<String> activeSports) {
    final sports = stadiums
        .map((s) => s.type)
        .where((t) => t.trim().isNotEmpty && activeSports.contains(t.trim()))
        .toSet()
        .toList();
    if (sports.isEmpty) return List<String>.from(activeSports);
    return sports;
  }
}
