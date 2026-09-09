import 'package:geolocator/geolocator.dart';
import 'auth_profile_service.dart';

/// Coordinates location querying and GPS governorate detection for auth profile.
class AuthLocationCoordinator {
  final AuthProfileService _profileService;
  Position? currentPosition;

  AuthLocationCoordinator({required AuthProfileService profileService})
      : _profileService = profileService;

  Future<({Position? position, String? governorate, String? error})> determineGPSGovernorate({
    bool force = false,
  }) async {
    final res = await _profileService.determineGPSGovernorate(force: force);
    if (res.position != null) {
      currentPosition = res.position;
    }
    return res;
  }
}
