import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../services/database_service.dart';

class StadiumProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  
  List<Stadium> _stadiums = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Stadium> get stadiums => _stadiums;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Listen to stadiums stream
  void listenToStadiums() {
    _isLoading = true;
    notifyListeners();

    _databaseService.getStadiums().listen(
      (stadiums) {
        _stadiums = stadiums;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Get stadium by ID
  Future<Stadium?> getStadiumById(String stadiumId) async {
    return await _databaseService.getStadiumById(stadiumId);
  }

  // Add stadium (Owner)
  Future<String?> addStadium(Stadium stadium) async {
    _isLoading = true;
    notifyListeners();

    try {
      String? stadiumId = await _databaseService.addStadium(stadium.toFirestore());
      _isLoading = false;
      notifyListeners();
      return stadiumId;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Update stadium
  Future<bool> updateStadium(String stadiumId, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      bool success = await _databaseService.updateStadium(stadiumId, data);
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Filter stadiums by location
  List<Stadium> filterByLocation(String location) {
    return _stadiums.where((stadium) => 
      stadium.location.toLowerCase().contains(location.toLowerCase())
    ).toList();
  }

  // Filter stadiums by price range
  List<Stadium> filterByPriceRange(double minPrice, double maxPrice) {
    return _stadiums.where((stadium) => 
      stadium.pricePerHour >= minPrice && stadium.pricePerHour <= maxPrice
    ).toList();
  }

  // Search stadiums
  List<Stadium> searchStadiums(String query) {
    return _stadiums.where((stadium) => 
      stadium.name.toLowerCase().contains(query.toLowerCase()) ||
      stadium.location.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
