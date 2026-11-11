import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/providers/auth/auth_draft_cleaner.dart';
import 'package:vsp_application/core/providers/auth/auth_location_coordinator.dart';
import 'package:vsp_application/core/providers/auth/auth_profile_service.dart';
import 'package:vsp_application/core/services/location_service.dart';

typedef LocationResult = ({Position? position, String? governorate, String? error});

class DeferredLocationProfile extends AuthProfileService {
  final calls = <Completer<LocationResult>>[];
  @override
  Future<LocationResult> determineGPSGovernorate({bool force = false}) {
    final pending = Completer<LocationResult>(); calls.add(pending);
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/geolocator');
  final position = Position(
    longitude: 32.9, latitude: 24.1, timestamp: DateTime(2026), accuracy: 10,
    altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('logout purges precise location/cache but preserves unrelated preferences', () async {
    SharedPreferences.setMockInitialValues({
      'last_lat': 24.1, 'last_lng': 32.9,
      'last_location_update': '2026-11-11T00:00:00',
      'last_resolved_governorate': 'Aswan', 'language': 'ar',
      'vsp_draft_stadium_other_1': 'other draft',
    });
    await AuthDraftCleaner.clearSessionDrafts('owner');
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['last_lat', 'last_lng', 'last_location_update', 'last_resolved_governorate']) {
      expect(prefs.containsKey(key), isFalse);
    }
    expect(prefs.getString('language'), 'ar');
    expect(prefs.getString('vsp_draft_stadium_other_1'), 'other draft');
  });

  test('logout without known UID still clears location', () async {
    SharedPreferences.setMockInitialValues({'last_lat': 24.1, 'last_resolved_governorate': 'Aswan'});
    await AuthDraftCleaner.clearSessionDrafts(null);
    expect((await SharedPreferences.getInstance()).containsKey('last_lat'), isFalse);
  });

  test('late previous-account location cannot repopulate cleared coordinator', () async {
    final profile = DeferredLocationProfile();
    final coordinator = AuthLocationCoordinator(profileService: profile);
    final query = coordinator.determineGPSGovernorate();
    coordinator.clear();
    profile.calls.single.complete((position: position, governorate: 'Aswan', error: null));
    final result = await query;
    expect(result.position, isNull); expect(result.governorate, isNull);
    expect(coordinator.currentPosition, isNull);
  });

  test('newest location request wins over older late response', () async {
    final profile = DeferredLocationProfile();
    final coordinator = AuthLocationCoordinator(profileService: profile);
    final old = coordinator.determineGPSGovernorate();
    final latest = coordinator.determineGPSGovernorate();
    profile.calls[1].complete((position: position, governorate: 'Aswan', error: null));
    expect((await latest).governorate, 'Aswan');
    profile.calls[0].complete((position: null, governorate: 'Cairo', error: null));
    expect((await old).governorate, isNull);
    expect(coordinator.currentPosition, same(position));
    coordinator.clear(); expect(coordinator.currentPosition, isNull);
  });

  test('corrupt cached date does not break refusal of optional GPS', () async {
    SharedPreferences.setMockInitialValues({'last_location_update': 'corrupt', 'last_resolved_governorate': 'Aswan'});
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'checkPermission') return LocationPermission.denied.index;
      throw StateError('Unexpected permission request: ${call.method}');
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final result = await LocationService().getThrottledLocation();
    expect(result.$1, isNull); expect(result.$2, 'Aswan');
    expect(calls, ['checkPermission']);
  });
}
