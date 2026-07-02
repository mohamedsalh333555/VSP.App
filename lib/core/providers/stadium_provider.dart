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

  // Getters
  List<Stadium> get stadiums => _isFilterActive ? _filteredStadiums : _stadiums;
  List<Stadium> get allStadiums => _stadiums;
  List<Stadium> get filteredStadiums => _filteredStadiums;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  bool get isFilterActive => _isFilterActive;
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
      final result = await _databaseService.getStadiumsPaginated(
        limit: 10,
        startAfter: _lastDocument,
        governorate: _isGeographicFallback ? null : _selectedGovernorate,
      );

      final List<Stadium> newStadiums = result['items'];
      _lastDocument = result['lastDoc'];

      // Phase 4: Fallback Logic - If city search is empty during initial refresh, show all stadiums
      if (newStadiums.isEmpty && _selectedGovernorate != null && isRefresh) {
        _isGeographicFallback = true;
        final fallbackResult = await _databaseService.getStadiumsPaginated(
          limit: 10,
          governorate: null, // Clear filter to show everything
        );
        final List<Stadium> fallbackStadiums = List<Stadium>.from(fallbackResult['items']);
        
        Position? userPosition;
        try {
          if (await Geolocator.isLocationServiceEnabled()) {
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
              userPosition = await Geolocator.getLastKnownPosition();
              userPosition ??= await Geolocator.getCurrentPosition(
                timeLimit: const Duration(seconds: 4),
              );
            }
          }
        } catch (e) {
          debugPrint('Error getting GPS location for fallback: $e');
        }

        if (userPosition != null) {
          fallbackStadiums.sort((a, b) {
            if (a.lat == null || a.lng == null) return 1;
            if (b.lat == null || b.lng == null) return -1;
            final distA = GeoHelper.calculateDistance(userPosition!.latitude, userPosition.longitude, a.lat!, a.lng!);
            final distB = GeoHelper.calculateDistance(userPosition.latitude, userPosition.longitude, b.lat!, b.lng!);
            return distA.compareTo(distB);
          });
        }
        
        _stadiums = fallbackStadiums;
        _lastDocument = fallbackResult['lastDoc'];
      } else {
        if (isRefresh) {
          _stadiums = newStadiums;
          _isGeographicFallback = false;
        } else {
          _stadiums.addAll(newStadiums);
        }
      }

      if (_stadiums.length < 10) {
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
    if (cleanQuery.isEmpty) return _stadiums;

    return _stadiums.where((stadium) => 
      stadium.name.toLowerCase().contains(cleanQuery) ||
      stadium.location.toLowerCase().contains(cleanQuery)
    ).toList();
  }

  // Apply complex filters
  void applyFilters(Map<String, dynamic> filters) {
    _isFilterActive = true;
    
    final Map<String, dynamic> sports = filters['sports'] is Map ? Map<String, bool>.from(filters['sports']) : {};
    final double minPrice = (filters['minPrice'] ?? 0.0).toDouble();
    final double maxPrice = (filters['maxPrice'] ?? 3000.0).toDouble();
    final int minRating = filters['minRating'] ?? 0;
    final Map<String, dynamic> services = filters['selectedServices'] is Map ? Map<String, bool>.from(filters['selectedServices']) : {};

    _filteredStadiums = _stadiums.where((stadium) {
      // Sport filter
      bool matchesSport = true;
      final activeSports = sports.entries.where((e) => e.value).map((e) => e.key).toList();
      if (activeSports.isNotEmpty) {
        matchesSport = activeSports.any((s) => stadium.type.toLowerCase() == s.toLowerCase());
      }

      // Price filter
      bool matchesPrice = stadium.pricePerHour >= minPrice && stadium.pricePerHour <= maxPrice;

      // Rating filter
      bool matchesRating = stadium.rating >= minRating;

      // Services filter (All selected services must be available at the stadium)
      bool matchesServices = true;
      if (services['Has Ball'] == true && !stadium.hasBall) matchesServices = false;
      if (services['Has Seats'] == true && !stadium.hasSeats) matchesServices = false;
      if (services['Professional Lighting'] == true && !stadium.hasJerash) matchesServices = false;

      return matchesSport && matchesPrice && matchesRating && matchesServices;
    }).toList();

    notifyListeners();
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
