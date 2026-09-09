import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vsp_application/core/providers/auth/auth_location_coordinator.dart';
import 'package:vsp_application/core/providers/auth/auth_profile_service.dart';

class FakeAuthProfileService extends AuthProfileService {
  final Position? mockPosition;
  final String? mockGovernorate;
  final String? mockError;

  FakeAuthProfileService({
    this.mockPosition,
    this.mockGovernorate,
    this.mockError,
  });

  @override
  Future<({Position? position, String? governorate, String? error})> determineGPSGovernorate({
    bool force = false,
  }) async {
    return (position: mockPosition, governorate: mockGovernorate, error: mockError);
  }
}

void main() {
  test('AuthLocationCoordinator caches position when returned', () async {
    final fakePosition = Position(
      longitude: 31.2357,
      latitude: 30.0444,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    final fakeService = FakeAuthProfileService(
      mockPosition: fakePosition,
      mockGovernorate: 'Cairo',
    );

    final coordinator = AuthLocationCoordinator(profileService: fakeService);
    expect(coordinator.currentPosition, isNull);

    final res = await coordinator.determineGPSGovernorate();
    expect(res.governorate, 'Cairo');
    expect(res.position, fakePosition);
    expect(coordinator.currentPosition, fakePosition);
  });
}
