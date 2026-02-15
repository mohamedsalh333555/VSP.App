import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../services/database_service.dart';

class StadiumProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  StreamSubscription? _stadiumSubscription;
  
  List<Stadium> _stadiums = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Stadium> get stadiums => _stadiums;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  // Listen to stadiums stream with lifecycle management
  void listenToStadiums() {
    _stadiumSubscription?.cancel();
    
    _setError(null);
    _setLoading(true);

    _stadiumSubscription = _databaseService.getStadiums().listen(
      (data) {
        _stadiums = data;
        _errorMessage = null;
        _setLoading(false);
      },
      onError: (error) {
        _setError('Failed to fetch stadiums: ${error.toString()}');
        _setLoading(false);
      },
    );
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

  // Clear error
  void clearError() {
    _setError(null);
  }

  @override
  void dispose() {
    _stadiumSubscription?.cancel();
    super.dispose();
  }
}
