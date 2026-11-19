import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../repositories/stadium_repository.dart';
import '../ui/tokens/vsp_tokens.dart';
import 'package:geolocator/geolocator.dart';
import '../services/fast_cache_service.dart';
import '../services/logger_service.dart';
import '../services/stadium/stadium_filter_service.dart';

class StadiumProvider with ChangeNotifier {
 final StadiumRepository _databaseService;
 StreamSubscription? _stadiumSubscription;
 
 List<Stadium> _stadiums = [];
 List<Stadium> _filteredStadiums = [];
 bool _isFilterActive = false;
 String? _activeQuickFilter; // 'night_shift' | 'no_deposit' | null
 bool _isLoading = false;
 bool _isLoadingMore = false;
 bool _hasMore = true;
 int? _lastDocument;
 // Invalidates in-flight player fetches when the active data scope changes.
 int _scopeGeneration = 0;
 int _discoveryRequestGeneration = 0;
 // Reuse one GPS snapshot across pages; refresh obtains a new snapshot.
 Position? _discoveryPagePosition;

 StadiumProvider({StadiumRepository? repository})
     : _databaseService = repository ?? StadiumRepository();
 String? _errorMessage;
 String? _selectedGovernorate;
 bool _isGeographicFallback = false;

 Map<String, dynamic>? _currentFilters;

 // Getters
 String? get activeQuickFilter => _activeQuickFilter;

 List<Stadium> get stadiums => _isFilterActive ? _filteredStadiums : _stadiums;

 void toggleQuickFilter(String filterKey) {
 if (_listeningOwnerId != null) return; // Owner data must be kept intact.
 if (_activeQuickFilter == filterKey) {
 _activeQuickFilter = null;
 } else {
 _activeQuickFilter = filterKey;
 }
 if (_isFilterActive && _currentFilters != null) {
   applyFilters(_currentFilters!);
 } else {
   _stadiums = [];
   _filteredStadiums = [];
   _lastDocument = null;
   _hasMore = true;
   _isGeographicFallback = false;
   _errorMessage = null;
   notifyListeners();
   fetchStadiums(isRefresh: true);
 }
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
 // Discovery belongs to the player scope. Never reuse a previous owner's
 // private stadium snapshot when the app switches back to player discovery.
 if (_listeningOwnerId != null) {
   _scopeGeneration++;
   _listeningOwnerId = null;
   _stadiumSubscription?.cancel();
   _stadiumSubscription = null;
   _stadiums = [];
   _filteredStadiums = [];
   _isFilterActive = false;
   _activeQuickFilter = null;
   _currentFilters = null;
   _errorMessage = null;
   _isLoading = false;
   _isLoadingMore = false;
   _lastDocument = null;
   _hasMore = true;
   isRefresh = true;
 }
 final requestGeneration = isRefresh ? ++_discoveryRequestGeneration : _discoveryRequestGeneration;
 final requestScopeGeneration = _scopeGeneration;
 if (!isRefresh && (!_hasMore || _isLoading || _isLoadingMore)) return;

 if (isRefresh) {
 _isLoadingMore = false;
 _lastDocument = null;
 _hasMore = true;
 _discoveryPagePosition = null;
 // A refresh must retry the user's chosen governorate before deciding
 // whether to fall back nationwide again.
 _isGeographicFallback = false;
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
 Position? userPosition = _discoveryPagePosition;
 // Explicit governorate selection uses server-side location filtering;
 // skip GPS permission/service calls that cannot affect this query.
 // Subsequent nearby pages reuse the same location so results do not jump.
 if ((_selectedGovernorate == null || _selectedGovernorate!.isEmpty) &&
     userPosition == null) {
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
 } catch (_) {
 debugPrint('GPS location unavailable (details redacted)');
 }
 if (requestGeneration == _discoveryRequestGeneration &&
     requestScopeGeneration == _scopeGeneration &&
     _listeningOwnerId == null) {
   _discoveryPagePosition = userPosition;
 }
 }

 // GPS permission/location lookups are asynchronous. A newer refresh, changed
 // governorate, or owner scope can invalidate this request while they run.
 // Do not send a superseded discovery query to Supabase.
 if (requestGeneration != _discoveryRequestGeneration ||
     requestScopeGeneration != _scopeGeneration ||
     _listeningOwnerId != null) {
   return;
 }

 // Governorate Filter Priority: If a specific governorate is selected by user,
 // strictly honor it. Use GPS nearby pre-sort ONLY when no governorate is selected.
 if ((_selectedGovernorate == null || _selectedGovernorate!.isEmpty) && userPosition != null) {
 final limit = _activeQuickFilter != null ? 100 : (isRefresh ? 10 : _stadiums.length + 10);
 final nearbyStadiums = await _databaseService.fetchNearbyStadiums(
 userPosition.latitude,
 userPosition.longitude,
 limit: limit,
 );

 if (requestGeneration != _discoveryRequestGeneration || requestScopeGeneration != _scopeGeneration || _listeningOwnerId != null) return;
 _stadiums = _activeQuickFilter == null
     ? nearbyStadiums
     : StadiumFilterService.applyQuickFilter(nearbyStadiums, _activeQuickFilter);
 _lastDocument = nearbyStadiums.length;
 // The nearby RPC caps at 100 rows and has no offset/filter parameters.
 // For quick-filtered nearby results, load that bounded nearest set once.
 // The RPC has a hard 100-row ceiling; a full 100-row response does
 // not mean another page can be fetched from this endpoint.
 _hasMore = _activeQuickFilter == null && limit < 100 && nearbyStadiums.length >= limit;
 _isGeographicFallback = false;
 } else {
 // Continue paging the same nationwide dataset when the initial
 // governorate search fell back; never mix local and fallback offsets.
 final result = await _databaseService.getStadiumsPaginated(
 limit: 10,
 startAfter: _lastDocument,
 governorate: _isGeographicFallback ? 'All' : _selectedGovernorate,
 quickFilter: _activeQuickFilter,
 );

 if (requestGeneration != _discoveryRequestGeneration || requestScopeGeneration != _scopeGeneration || _listeningOwnerId != null) return;
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
            quickFilter: _activeQuickFilter,
          );
          if (requestGeneration != _discoveryRequestGeneration || requestScopeGeneration != _scopeGeneration || _listeningOwnerId != null) return;
          final List<Stadium> fallbackStadiums = fallbackResult['items'];
          if (fallbackStadiums.isNotEmpty) {
            _stadiums = fallbackStadiums;
            _lastDocument = fallbackResult['lastDoc'];
            _isGeographicFallback = true;
            // Page exhaustion must be calculated from the fallback response,
            // not the empty governorate response.
            _hasMore = fallbackStadiums.length == 10;
          } else {
            _stadiums = [];
            _hasMore = false;
            _isGeographicFallback = false;
          }
        } else {
          _stadiums = newStadiums;
          _isGeographicFallback = false;
        }
      } else {
        _stadiums.addAll(newStadiums);
      }

 if (!_isGeographicFallback || !isRefresh) {
   _hasMore = newStadiums.length == 10;
 }
 }

 _errorMessage = null;
 if (_stadiums.isNotEmpty && (_selectedGovernorate == null || _selectedGovernorate!.isEmpty)) {
 FastCacheService.cacheStadiums(_stadiums);
 }
 notifyListeners();
 } catch (e) {
 if (requestGeneration == _discoveryRequestGeneration && requestScopeGeneration == _scopeGeneration && _listeningOwnerId == null) {
   VSPLogger.e('Stadium discovery fetch failed (details redacted)');
   _setError('stadium_load_failed');
 }
 } finally {
 if (requestGeneration == _discoveryRequestGeneration && requestScopeGeneration == _scopeGeneration && _listeningOwnerId == null) {
   if (isRefresh) {
     _setLoading(false);
   } else {
     _isLoadingMore = false;
     notifyListeners();
   }
 }
 }
 }

  /// Transition from owner-only venue data into public player discovery.
  /// The caller must have verified that the current account is a player.
  void enterPlayerDiscoveryScope() {
    if (_listeningOwnerId == null) return;
    _scopeGeneration++;
    _discoveryRequestGeneration++;
    _listeningOwnerId = null;
    _stadiumSubscription?.cancel();
    _stadiumSubscription = null;
    _stadiums = [];
    _filteredStadiums = [];
    _isFilterActive = false;
    _activeQuickFilter = null;
    _currentFilters = null;
    _selectedGovernorate = null;
    _isGeographicFallback = false;
    _errorMessage = null;
    _isLoading = false;
    _isLoadingMore = false;
    _lastDocument = null;
    _hasMore = true;
    notifyListeners();
  }

  String? _listeningOwnerId;

  // Listen specifically to owner's stadiums
  void listenToOwnerStadiums(String ownerId, {bool forceRefresh = false}) {
    final scopeChanged = _listeningOwnerId != ownerId;
    if (!forceRefresh && !scopeChanged && _stadiumSubscription != null && _stadiums.isNotEmpty) {
      return;
    }

    if (scopeChanged) {
      // A different owner must never see the previous owner's stadium cache.
      _stadiums = [];
      _filteredStadiums = [];
      _isFilterActive = false;
      _activeQuickFilter = null;
      _currentFilters = null;
      _isLoading = false;
      _isLoadingMore = false;
    }

    final ownerGeneration = ++_scopeGeneration;
    _listeningOwnerId = ownerId;
    _stadiumSubscription?.cancel();

    _setError(null);
    _setLoading(true);

    _stadiumSubscription = _databaseService.getOwnerStadiums(ownerId).listen(
      (data) {
        if (_listeningOwnerId != ownerId || ownerGeneration != _scopeGeneration) return;
        _stadiums = data;
        _errorMessage = null;
        _isLoading = false;
        // Every authoritative update must notify, not just the initial load.
        notifyListeners();
      },
      onError: (_) {
        if (_listeningOwnerId != ownerId || ownerGeneration != _scopeGeneration) return;
        _setError('owner_stadium_sync_failed');
        _setLoading(false);
      },
    );
  }

 // Get stadium by ID
 Future<Stadium?> getStadiumById(String stadiumId) async {
    final operationScope = _scopeGeneration;
    try {
      final stadium = await _databaseService.getStadiumByIdStrict(stadiumId);
      if (operationScope != _scopeGeneration) return null;
      return stadium;
    } catch (_) {
      if (operationScope != _scopeGeneration) return null;
      _setError('stadium_fetch_failed');
      rethrow;
    }
  }

  // Add stadium (Owner)
 Future<String?> addStadium(Stadium stadium) async {
    final operationScope = _scopeGeneration;
    final ownerAtStart = _listeningOwnerId;
    _setError(null);
    _setLoading(true);

    try {
      final stadiumId = await _databaseService.addStadium(stadium.toFirestore());
      if (operationScope != _scopeGeneration) {
        // A same-owner refresh can preserve the write result. A different
        // account must not receive a previous owner's created venue ID.
        return ownerAtStart == _listeningOwnerId ? stadiumId : null;
      }
      _setLoading(false);
      return stadiumId;
    } catch (_) {
      if (operationScope != _scopeGeneration) return null;
      _setError('stadium_create_failed');
      _setLoading(false);
      rethrow;
    }
  }

  // Update stadium
 Future<bool> updateStadium(String stadiumId, Map<String, dynamic> data) async {
    final operationScope = _scopeGeneration;
    final ownerAtStart = _listeningOwnerId;
    _setError(null);
    _setLoading(true);

    try {
      final success = await _databaseService.updateStadium(stadiumId, data);
      if (operationScope != _scopeGeneration) {
        return ownerAtStart == _listeningOwnerId && success;
      }
      _setLoading(false);
      return success;
    } catch (_) {
      if (operationScope != _scopeGeneration) return false;
      _setError('stadium_update_failed');
      _setLoading(false);
      rethrow;
    }
  }

  List<Stadium> filterByLocation(String location) =>
      StadiumFilterService.filterByLocation(_stadiums, location);

 // Filter stadiums by governorate
 void applyGovernorateFilter(String? governorate) {
 if (_listeningOwnerId != null) return;
 if (_selectedGovernorate == governorate) return;
 
 _selectedGovernorate = governorate;
 _stadiums = [];
 _filteredStadiums = [];
 _lastDocument = null;
 _hasMore = true;
 _isFilterActive = false; 
 _isGeographicFallback = false;
 _errorMessage = null;
 notifyListeners(); // Clear the previous governorate before the async query.
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

  List<String> get availableSportTypes => List<String>.from(VSPConstants.activeSports);

 // Apply complex filters with server-side pagination support
 void applyFilters(Map<String, dynamic> filters) {
 if (_listeningOwnerId != null) return;
 _currentFilters = filters;
 _isFilterActive = true;
 _stadiums = [];
 _filteredStadiums = [];
 _lastDocument = null;
 _hasMore = true;
 _errorMessage = null;
 notifyListeners(); // Prevent earlier filter results from lingering.
 final List<String> sports = filters['sports'] is List ? List<String>.from(filters['sports']) : [];
 final String? location = filters['location'] as String?;
 final List<String> sizes = filters['sizes'] is List ? List<String>.from(filters['sizes']) : [];
 final double? minPrice = (filters['minPrice'] as num?)?.toDouble();
 final double? maxPrice = (filters['maxPrice'] as num?)?.toDouble();
 final bool noDepositOnly = filters['noDepositOnly'] == true;
 final List<String> amenities = filters['amenities'] is List ? List<String>.from(filters['amenities']) : [];
 final String? floorType = filters['floorType'] as String?;
 final String? searchQuery = filters['searchQuery'] as String?;
 final String? sortBy = filters['sortBy'] as String?;

 // Fetch filtered data directly from Supabase
 fetchStadiumsWithParams(
 isRefresh: true,
 governorate: location ?? _selectedGovernorate,
 sportTypes: sports.isNotEmpty ? sports : null,
 pitchSizes: sizes.isNotEmpty ? sizes : null,
 minPrice: minPrice,
 maxPrice: maxPrice,
 noDepositOnly: noDepositOnly,
 amenities: amenities,
 floorType: floorType,
 searchQuery: searchQuery,
 sortBy: sortBy,
 );
 }

 Future<void> fetchStadiumsWithParams({
 bool isRefresh = false,
 String? governorate,
 String? sportType,
 String? pitchSize,
 List<String>? sportTypes,
 List<String>? pitchSizes,
 double? minPrice,
 double? maxPrice,
 bool? noDepositOnly,
 List<String>? amenities,
 String? floorType,
 String? searchQuery,
 String? sortBy,
 }) async {
 if (_listeningOwnerId != null) return;
 final requestGeneration = isRefresh ? ++_discoveryRequestGeneration : _discoveryRequestGeneration;
 final requestScopeGeneration = _scopeGeneration;
 if (!isRefresh && (!_hasMore || _isLoading || _isLoadingMore)) return;

 if (isRefresh) {
 _isLoadingMore = false;
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
 sportTypes: sportTypes,
 pitchSizes: pitchSizes,
 minPrice: minPrice,
 maxPrice: maxPrice,
 noDepositOnly: noDepositOnly,
 amenities: amenities,
 quickFilter: _activeQuickFilter,
 floorType: floorType,
 searchQuery: searchQuery,
 sortBy: sortBy,
 );

 if (requestGeneration != _discoveryRequestGeneration || requestScopeGeneration != _scopeGeneration || _listeningOwnerId != null) return;
 final List<Stadium> rawItems = result['items'];
 // Amenity filters are already applied by the repository before pagination.
 final List<Stadium> newStadiums = rawItems;
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
 } catch (_) {
 if (requestGeneration == _discoveryRequestGeneration && requestScopeGeneration == _scopeGeneration && _listeningOwnerId == null) {
   VSPLogger.e('Filtered stadium fetch failed (details redacted)');
   _setError('stadium_load_failed');
 }
 } finally {
 if (requestGeneration == _discoveryRequestGeneration && requestScopeGeneration == _scopeGeneration && _listeningOwnerId == null) {
   if (isRefresh) {
     _setLoading(false);
   } else {
     _isLoadingMore = false;
     notifyListeners();
   }
 }
 }
 }

 // Sort stadiums by distance
  void sortByDistance(Position? userPosition) {
    if (_listeningOwnerId != null || userPosition == null) return;
    StadiumFilterService.sortStadiumsByDistance(_stadiums, userPosition.latitude, userPosition.longitude);
    if (_isFilterActive) {
      StadiumFilterService.sortStadiumsByDistance(_filteredStadiums, userPosition.latitude, userPosition.longitude);
    }
    notifyListeners();
  }

 // Reset all filters
 Future<void> clearFilters() async {
 if (_listeningOwnerId != null) return;
 _isFilterActive = false;
 _currentFilters = null;
 _filteredStadiums = [];
 _activeQuickFilter = null;
 _selectedGovernorate = null;
 _isGeographicFallback = false;
 _lastDocument = null;
 _hasMore = true;
 _stadiums = [];
 _errorMessage = null;
 notifyListeners();
 await fetchStadiums(isRefresh: true);
 }

 // Clear error
 void clearError() {
 _setError(null);
 }

 // Phase 2: Stadium Deletion Safeguard
 Future<bool> deleteStadium(String stadiumId) async {
    final operationScope = _scopeGeneration;
    final ownerAtStart = _listeningOwnerId;
    _setError(null);
    _setLoading(true);

    try {
      final success = await _databaseService.deleteStadium(stadiumId);
      if (operationScope != _scopeGeneration) {
        return ownerAtStart == _listeningOwnerId && success;
      }
      if (success) {
        // Do not mutate another owner's cached venue with this operation.
        _stadiums.removeWhere((s) => s.id == stadiumId);
        if (_isFilterActive) {
          _filteredStadiums.removeWhere((s) => s.id == stadiumId);
        }
        _setLoading(false);
        return true;
      }
      _setError('Failed to delete stadium safely. Check your connection.');
      _setLoading(false);
      return false;
    } catch (_) {
      if (operationScope != _scopeGeneration) return false;
      VSPLogger.e('Stadium deletion failed (details redacted)');
      _setError('stadium_delete_failed');
      _setLoading(false);
      return false;
    }
  }

  @override
 void dispose() {
 // Invalidate in-flight discovery and owner-stream callbacks before canceling.
 _scopeGeneration++;
 _discoveryRequestGeneration++;
 _listeningOwnerId = null;
 _stadiumSubscription?.cancel();
 super.dispose();
 }
}
