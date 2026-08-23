import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../repositories/stadium_repository.dart';
import '../utils/geo_helper.dart';
import 'package:geolocator/geolocator.dart';

class StadiumProvider with ChangeNotifier {
  final StadiumRepository _databaseService = StadiumRepository();
  StreamSubscription? _stadiumSubscription;
  
  List<Stadium> _stadiums = [];
  List<Stadium> _filteredStadiums = [];
  bool _isFilterActive = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int? _lastDocument;
  String? _errorMessage;
  String? _selectedGovernorate;
  bool _isGeographicFallback = false;

  Map<String, dynamic>? _currentFilters;

  // Getters
  List<Stadium> get stadiums => _isFilterActive ? _filteredStadiums : _stadiums;
  List<Stadium> get allStadiums => _stadiums;
  List<Stadium> get filteredStadiums => _filteredStadiums;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  bool get isFilterActive => _isFilterActive;
  Map<String, dynamic>? get currentFilters => _currentFilters;
  String? get selectedGovernorate => _selectedGovernorate;
  bool get isGeographicFallback => _isGeographicFallback;

  // Private helpers to manage state consistently
  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Fetch stadiums with pagination
  Future<void> fetchStadiums({bool isRefresh = false}) async {
    if (_isLoading || (_isLoadingMore && !isRefresh)) return;

    if (isRefresh) {
      _lastDocument = null;
      _hasMore = true;
      if (_stadiums.isEmpty) {
        _setLoading(true);
      }
    } else {
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      // 🛡️ Discovery and Search Geo-Matching: Database-Level Geodistance Query
      // Check if user's geographic location is available. If active, immediately fetch
      // the pre-sorted list from the database RPC instead of client-side loops.
      Position? userPosition;
      try {
        if (await Geolocator.isLocationServiceEnabled()) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            userPosition = await Geolocator.getLastKnownPosition();
            userPosition ??= await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(timeLimit: Duration(seconds: 2)),
            );
          }
        }
      } catch (e) {
        debugPrint('Error getting GPS location: $e');
      }

      // 🛡️ Governorate Filter Priority: If a specific governorate is selected by user,
      // strictly honor it. Use GPS nearby pre-sort ONLY when no governorate is selected.
      if ((_selectedGovernorate == null || _selectedGovernorate!.isEmpty) && userPosition != null) {
        final limit = isRefresh ? 10 : _stadiums.length + 10;
        final nearbyStadiums = await _databaseService.fetchNearbyStadiums(
          userPosition.latitude,
          userPosition.longitude,
          limit: limit,
        );

        _stadiums = nearbyStadiums;
        _lastDocument = _stadiums.length;
        _hasMore = nearbyStadiums.length >= limit;
        _isGeographicFallback = false;
      } else {
        final result = await _databaseService.getStadiumsPaginated(
          limit: 10,
          startAfter: _lastDocument,
          governorate: _selectedGovernorate,
        );

        final List<Stadium> newStadiums = result['items'];
        _lastDocument = result['lastDoc'];

        if (isRefresh) {
          _stadiums = newStadiums;
          _isGeographicFallback = false;
        } else {
          _stadiums.addAll(newStadiums);
        }

        if (newStadiums.length < 10) {
          _hasMore = false;
        }
      }

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch stadiums: ${e.toString()}');
    } finally {
      if (isRefresh) {
        _setLoading(false);
      } else {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  // Listen specifically to owner's stadiums
  void listenToOwnerStadiums(String ownerId) {
    _stadiumSubscription?.cancel();
    
    _setError(null);
    _setLoading(true);

    _stadiumSubscription = _databaseService.getOwnerStadiums(ownerId).listen(
      (data) {
        _stadiums = data;
        _errorMessage = null;
        _setLoading(false);
      },
      onError: (error) {
        _setError('Failed to fetch your stadiums: ${error.toString()}');
        _setLoading(false);
      },
    );
  }

  // Get stadium by ID
  Future<Stadium?> getStadiumById(String stadiumId) async {
    try {
      return await _databaseService.getStadiumById(stadiumId);
    } catch (e) {
      debugPrint('Error fetching stadium by ID: $e');
      return null;
    }
  }

  // Add stadium (Owner)
  Future<String?> addStadium(Stadium stadium) async {
    _setError(null);
    _setLoading(true);

    try {
      String? stadiumId = await _databaseService.addStadium(stadium.toFirestore());
      _setLoading(false);
      return stadiumId;
    } catch (e) {
      _setError('Failed to add stadium: ${e.toString()}');
      _setLoading(false);
      return null;
    }
  }

  // Update stadium
  Future<bool> updateStadium(String stadiumId, Map<String, dynamic> data) async {
    _setError(null);
    _setLoading(true);

    try {
      bool success = await _databaseService.updateStadium(stadiumId, data);
      _setLoading(false);
      return success;
    } catch (e) {
      _setError('Failed to update stadium: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Filter stadiums by location (Robust)
  List<Stadium> filterByLocation(String location) {
    final query = location.trim().toLowerCase();
    if (query.isEmpty) return _stadiums;
    
    return _stadiums.where((stadium) => 
      stadium.location.toLowerCase().contains(query)
    ).toList();
  }

  // Filter stadiums by governorate
  void applyGovernorateFilter(String? governorate) {
    if (_selectedGovernorate == governorate) return;
    
    _selectedGovernorate = governorate;
    _stadiums = [];
    _filteredStadiums = [];
    _lastDocument = null;
    _hasMore = true;
    _isFilterActive = false; 
    _isGeographicFallback = false;
    
    fetchStadiums(isRefresh: true);
  }

  // Filter stadiums by price range
  List<Stadium> filterByPriceRange(double minPrice, double maxPrice) {
    return _stadiums.where((stadium) => 
      stadium.pricePerHour >= minPrice && stadium.pricePerHour <= maxPrice
    ).toList();
  }

  // Search stadiums (Robust)
  List<Stadium> searchStadiums(String query) {
    final cleanQuery = query.trim().toLowerCase();
    final sourceList = _isFilterActive ? _filteredStadiums : _stadiums;
    if (cleanQuery.isEmpty) return sourceList;

    return sourceList.where((stadium) => 
      stadium.name.toLowerCase().contains(cleanQuery) ||
      stadium.location.toLowerCase().contains(cleanQuery)
    ).toList();
  }

  double get maxStadiumPrice {
    if (_stadiums.isEmpty) return 2000.0;
    final maxP = _stadiums.map((s) => s.pricePerHour).reduce((a, b) => a > b ? a : b);
    return maxP > 0 ? (maxP / 50).ceil() * 50.0 : 2000.0;
  }

  /// Returns unique registered sports dynamically from stadiums database
  List<String> get availableSportTypes {
    final sports = _stadiums.map((s) => s.type).where((t) => t.trim().isNotEmpty).toSet().toList();
    if (sports.isEmpty) return ['Football', 'Padel'];
    return sports;
  }

  // Private helper to check dynamic features mapping safely
  bool _checkAmenity(Stadium stadium, String amenity) {
    final dynamic feats = stadium.features;
    final Map<dynamic, dynamic> featMap = feats is Map ? feats : {};

    // 1. Payment & Deposit
    if (amenity == 'No Deposit Needed' || amenity == 'حجز بدون عربون (دفع نقدي)') {
      return !stadium.needsDeposit;
    }

    // 2. Real Owner Amenities (Strictly matching owner inputs)
    if (amenity == 'Showers & Baths' || amenity == 'دش وحمام') {
      return featMap['bathOption'] == 'Yes' || featMap['hasShower'] == true || featMap['shower'] == true;
    }
    if (amenity == 'Changing Rooms' || amenity == 'غرف تغيير ملابس') {
      return featMap['changingRoom'] == true || featMap['changingRooms'] == true || featMap['hasChangingRooms'] == true;
    }
    if (amenity == 'Night Floodlights' || amenity == 'كشافات إضاءة ليلاً') {
      return stadium.hasJerash || featMap['hasLighting'] == true || featMap['lighting'] == true;
    }
    if (amenity == 'Cafeteria & Drinks' || amenity == 'كافتيريا ومشروبات') {
      return stadium.cafeteria > 0 || featMap['cafeteria'] == true || featMap['hasCafeteria'] == true;
    }
    if (amenity == 'Ball Provided' || amenity == 'كرة متوفرة' || amenity == 'كرة') {
      return stadium.hasBall || featMap['hasBall'] == true;
    }
    if (amenity == 'Spectator Seats' || amenity == 'مدرجات جمهور' || amenity == 'مقاعد') {
      return stadium.hasSeats || featMap['hasSeats'] == true;
    }
    if (amenity == 'Garage & Parking' || amenity == 'جراج سيارات') {
      return featMap['garage'] == true || featMap['hasGarage'] == true || featMap['parking'] == true;
    }

    // Fallback checks
    final key = amenity.replaceAll(' ', '').toLowerCase();
    return featMap[key] == true || featMap['has${amenity.replaceAll(' ', '')}'] == true;
  }

  // Apply complex filters with server-side pagination support
  void applyFilters(Map<String, dynamic> filters) {
    _currentFilters = filters;
    _isFilterActive = true;
    _stadiums = [];
    _filteredStadiums = [];
    _lastDocument = null;
    _hasMore = true;
    
    final List<String> sports = filters['sports'] is List ? List<String>.from(filters['sports']) : [];
    final String? location = filters['location'] as String?;
    final List<String> sizes = filters['sizes'] is List ? List<String>.from(filters['sizes']) : [];
    final double? minPrice = (filters['minPrice'] as num?)?.toDouble();
    final double? maxPrice = (filters['maxPrice'] as num?)?.toDouble();
    final bool noDepositOnly = filters['noDepositOnly'] == true;
    final List<String> amenities = filters['amenities'] is List ? List<String>.from(filters['amenities']) : [];

    // Fetch filtered data directly from Supabase
    fetchStadiumsWithParams(
      isRefresh: true,
      governorate: location ?? _selectedGovernorate,
      sportType: sports.isNotEmpty ? sports.first : null,
      pitchSize: sizes.isNotEmpty ? sizes.first : null,
      minPrice: minPrice,
      maxPrice: maxPrice,
      noDepositOnly: noDepositOnly,
      amenities: amenities,
    );
  }

  Future<void> fetchStadiumsWithParams({
    bool isRefresh = false,
    String? governorate,
    String? sportType,
    String? pitchSize,
    double? minPrice,
    double? maxPrice,
    bool? noDepositOnly,
    List<String>? amenities,
  }) async {
    if (_isLoading || (_isLoadingMore && !isRefresh)) return;

    if (isRefresh) {
      _lastDocument = null;
      _hasMore = true;
      _setLoading(true);
    } else {
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final result = await _databaseService.getStadiumsPaginated(
        limit: 10,
        startAfter: _lastDocument,
        governorate: governorate,
        sportType: sportType,
        pitchSize: pitchSize,
        minPrice: minPrice,
        maxPrice: maxPrice,
        noDepositOnly: noDepositOnly,
      );

      final List<Stadium> rawItems = result['items'];
      final List<Stadium> newStadiums = (amenities != null && amenities.isNotEmpty)
          ? rawItems.where((s) => amenities.every((a) => _checkAmenity(s, a))).toList()
          : rawItems;
      _lastDocument = result['lastDoc'];

      if (isRefresh) {
        _stadiums = newStadiums;
        _filteredStadiums = newStadiums;
      } else {
        _stadiums.addAll(newStadiums);
        _filteredStadiums.addAll(newStadiums);
      }

      if (rawItems.length < 10) {
        _hasMore = false;
      }

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _setError('Failed to fetch stadiums: ${e.toString()}');
    } finally {
      if (isRefresh) {
        _setLoading(false);
      } else {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  // Sort stadiums by distance
  void sortByDistance(Position? userPosition) {
    if (userPosition == null) return;

    _stadiums.sort((a, b) {
      if (a.lat == null || a.lng == null) return 1;
      if (b.lat == null || b.lng == null) return -1;

      final distA = GeoHelper.calculateDistance(userPosition.latitude, userPosition.longitude, a.lat!, a.lng!);
      final distB = GeoHelper.calculateDistance(userPosition.latitude, userPosition.longitude, b.lat!, b.lng!);
      
      return distA.compareTo(distB);
    });

    if (_isFilterActive) {
      _filteredStadiums.sort((a, b) {
        if (a.lat == null || a.lng == null) return 1;
        if (b.lat == null || b.lng == null) return -1;

        final distA = GeoHelper.calculateDistance(userPosition.latitude, userPosition.longitude, a.lat!, a.lng!);
        final distB = GeoHelper.calculateDistance(userPosition.latitude, userPosition.longitude, b.lat!, b.lng!);
        
        return distA.compareTo(distB);
      });
    }

    notifyListeners();
  }

  // Reset all filters
  void clearFilters() {
    _isFilterActive = false;
    _currentFilters = null;
    _filteredStadiums = [];
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _setError(null);
  }

  // Phase 2: Stadium Deletion Safeguard
  Future<bool> deleteStadium(String stadiumId) async {
    _setError(null);
    _setLoading(true);

    try {
      bool success = await _databaseService.deleteStadium(stadiumId);
      if (success) {
        // Remove from local list if present
        _stadiums.removeWhere((s) => s.id == stadiumId);
        if (_isFilterActive) {
          _filteredStadiums.removeWhere((s) => s.id == stadiumId);
        }
        _setLoading(false);
        return true;
      } else {
        _setError('Failed to delete stadium safely. Check your connection.');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Error during stadium deletion: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  @override
  void dispose() {
    _stadiumSubscription?.cancel();
    super.dispose();
  }
}
