import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_device/safe_device.dart';
import 'logger_service.dart';
import '../constants/egypt_governorates.dart';

class LocationService {
  Future<(Position?, String?)> getThrottledLocation({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateStr = prefs.getString('last_location_update');
      final lastLat = prefs.getDouble('last_lat') ?? 0.0;
      final lastLng = prefs.getDouble('last_lng') ?? 0.0;

      final now = DateTime.now();
      
      bool timeThresholdMet = force || lastUpdateStr == null || 
          now.difference(DateTime.parse(lastUpdateStr)).inHours >= 24;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return (null, null);
      }
      if (permission == LocationPermission.deniedForever) return (null, null);

      // 🛡️ Security Guard: Jailbreak and Mock Location Detection with safety timeouts
      try {
        final bool isJailBroken = await SafeDevice.isJailBroken.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            VSPLogger.w("⚠️ SafeDevice jailbreak check timed out. Defaulting to safe state.");
            return false;
          },
        );
        final bool isMockLocation = await SafeDevice.isMockLocation.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            VSPLogger.w("⚠️ SafeDevice mock location check timed out. Defaulting to safe state.");
            return false;
          },
        );
        if (isJailBroken || isMockLocation) {
          VSPLogger.w("⚠️ Device Security Alert: Jailbroken=$isJailBroken, MockLocation=$isMockLocation");
          return (null, "mock_location_detected");
        }
      } catch (e) {
        VSPLogger.e("Error performing safe device checks: $e");
        return (null, null);
      }

      // 🌍 Get Position safely using getLastKnownPosition first or getCurrentPosition with a strict timeLimit
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
        position ??= await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
            timeLimit: const Duration(seconds: 4),
          );
      } catch (e) {
        VSPLogger.w("Could not obtain current GPS position: $e");
      }

      if (position == null) {
        final cachedGov = prefs.getString('last_resolved_governorate');
        return (null, cachedGov);
      }

      double distanceInMeters = Geolocator.distanceBetween(
        lastLat, lastLng, position.latitude, position.longitude
      );

      if (force || timeThresholdMet || distanceInMeters > 5000) {
        VSPLogger.i("🌍 GPS Optimized: Threshold met. Fetching placemark...");
        
        List<Placemark> placemarks = [];
        try {
          placemarks = await placemarkFromCoordinates(
            position.latitude, 
            position.longitude,
          ).timeout(const Duration(seconds: 4));
        } catch (e) {
          VSPLogger.w("Geocoding lookup failed: $e");
        }

        if (placemarks.isNotEmpty) {
          final rawName = placemarks.first.administrativeArea ?? placemarks.first.subAdministrativeArea ?? placemarks.first.locality;
          final newGov = EgyptGovernorates.resolveGoogleName(rawName);
          
          await prefs.setString('last_location_update', now.toIso8601String());
          await prefs.setDouble('last_lat', position.latitude);
          await prefs.setDouble('last_lng', position.longitude);
          if (newGov != null) {
            await prefs.setString('last_resolved_governorate', newGov);
          }

          return (position, newGov);
        }
        final cachedGov = prefs.getString('last_resolved_governorate');
        return (position, cachedGov);
      } else {
        VSPLogger.i("🌍 GPS Optimized: Using cached location (Throttled)");
        final cachedGov = prefs.getString('last_resolved_governorate');
        // If throttled, we still return the position so UI can show distance
        return (position, cachedGov);
      }
    } catch (e) {
      VSPLogger.w('Error fetching location: $e');
    }
    return (null, null);
  }
}



