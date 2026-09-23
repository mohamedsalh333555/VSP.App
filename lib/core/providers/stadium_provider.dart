import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../repositories/stadium_repository.dart';
import '../ui/tokens/vsp_tokens.dart';
import 'package:geolocator/geolocator.dart';
import '../services/fast_cache_service.dart';
import '../services/stadium/stadium_filter_service.dart';

class StadiumProvider with ChangeNotifier {
 final StadiumRepository _databaseService = StadiumRepository();
 StreamSubscription? _stadiumSubscription;
 
 List<Stadium> _stadiums = [];
 List<Stadium> _filteredStadiums = [];
 bool _isFilterActive = false;
 String? _activeQuickFilter; // 'night_shift' | 'no_deposit' | null
 bool _isLoading = false;
 bool _isLoadingMore = false;
 bool _hasMore = true;
 int? _lastDocument;

 StadiumProvider();
 String? _errorMessage;
 String? _selectedGovernorate;
 bool _isGeographicFallback = false;

 Map<String, dynamic>? _currentFilters;

 // Getters
 String? get activeQuickFilter => _activeQuickFilter;

 List<Stadium> get stadiums {
    final baseList = _isFilterActive ? _filteredStadiums : _stadiums;
    return StadiumFilterService.applyQuickFilter(baseList, _activeQuickFilter);
  }

 void toggleQuickFilter(String filterKey) {
 if (_activeQuickFilter == filterKey) {
 _activeQuickFilter = null;
 } else {
 _activeQuickFilter = filterKey;
 }
 notifyListeners();
 }

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
 // Discovery and Search Geo-Matching: Database-Level Geodistance Query
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

 // Governorate Filter Priority: If a specific governorate is selected by user,
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
        if (newStadiums.isEmpty &&
            _selectedGovernorate != null &&
            _selectedGovernorate!.isNotEmpty &&
            _selectedGovernorate != 'All') {
          // 🚀 Smart Fallback: Fetch available verified stadiums across Egypt
          final fallbackResult = await _databaseService.getStadiumsPaginated(
            limit: 10,
            startAfter: null,
            governorate: 'All',
          );
          final List<Stadium> fallbackStadiums = fallbackResult['items'];
          if (fallbackStadiums.isNotEmpty) {
            _stadiums = fallbackStadiums;
            _lastDocument = fallbackResult['lastDoc'];
            _isGeographicFallback = true;
          } else {
            _stadiums = [];
            _isGeographicFallback = false;
          }
        } else {
          _stadiums = newStadiums;
          _isGeographicFallback = false;
        }
      } else {
        _stadiums.addAll(newStadiums);
      }

 if (newStadiums.length < 10) {
 _hasMore = false;
 }
 }

 _errorMessage = null;
 if (_stadiums.isNotEmpty && (_selectedGovernorate == null || _selectedGovernorate!.isEmpty)) {
 FastCacheService.cacheStadiums(_stadiums);
 }
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

  String? _listeningOwnerId;

  // Listen specifically to owner's stadiums
  void listenToOwnerStadiums(String ownerId, {bool forceRefresh = false}) {
    if (!forceRefresh && _listeningOwnerId == ownerId && _stadiumSubscription != null && _stadiums.isNotEmpty) {
      return;
    }
    _listeningOwnerId = ownerId;
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
        _stadiums = [];
        _filteredStadiums = [];
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
 _setError('Failed to fetch stadium: ${e.toString()}');
 rethrow;
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
 rethrow;
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
 rethrow;
 }
 }

  List<Stadium> filterByLocation(String location) =>
      StadiumFilterService.filterByLocation(_stadiums, location);

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

  List<Stadium> filterByPriceRange(double minPrice, double maxPrice) =>
      StadiumFilterService.filterByPriceRange(_stadiums, minPrice, maxPrice);

  List<Stadium> searchStadiums(String query) =>
      StadiumFilterService.searchStadiums(_isFilterActive ? _filteredStadiums : _stadiums, query);

 double get maxStadiumPrice {
 if (_stadiums.isEmpty) return 2000.0;
 final maxP = _stadiums.map((s) => s.pricePerHour).reduce((a, b) => a > b ? a : b);
 return maxP > 0 ? (maxP / 50).ceil() * 50.0 : 2000.0;
 }

  List<String> get availableSportTypes =>
      StadiumFilterService.getAvailableSportTypes(_stadiums, VSPConstants.activeSports);

 // Private helper to check dynamic features mapping safely
 bool _checkAmenity(Stadium stadium, String amenity) {
    return StadiumFilterService.checkAmenity(stadium, amenity);
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
    StadiumFilterService.sortStadiumsByDistance(_stadiums, userPosition.latitude, userPosition.longitude);
    if (_isFilterActive) {
      StadiumFilterService.sortStadiumsByDistance(_filteredStadiums, userPosition.latitude, userPosition.longitude);
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
