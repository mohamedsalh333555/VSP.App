import 'package:geolocator/geolocator.dart';
import 'auth_profile_service.dart';

/// Coordinates location querying and GPS governorate detection for auth profile.
class AuthLocationCoordinator {
  final AuthProfileService _profileService;
  Position? currentPosition;
  int _generation = 0;

  AuthLocationCoordinator({required AuthProfileService profileService})
      : _profileService = profileService;

  void clear() {
    _generation++;
    currentPosition = null;
  }

  Future<({Position? position, String? governorate, String? error})> determineGPSGovernorate({
    bool force = false,
  }) async {
    final generation = ++_generation;
    final res = await _profileService.determineGPSGovernorate(force: force);
    if (generation != _generation) {
      return (position: null, governorate: null, error: null);
    }
    if (res.position != null) {
      currentPosition = res.position;
    }
    return res;
  }
}
