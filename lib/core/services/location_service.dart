import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_device/safe_device.dart';
import 'logger_service.dart';
import '../constants/egypt_governorates.dart';

class LocationService {
 static int _cacheGeneration = 0;
 static Future<void> _cacheClear = Future<void>.value();
 static const _cacheKeys = [
   'last_location_update', 'last_lat', 'last_lng', 'last_resolved_governorate',
 ];

 /// Invalidate pending GPS results before removing this session's disk cache.
 static Future<void> clearCachedLocation() {
   _cacheGeneration++;
   return _cacheClear = _removeCachedLocation();
 }

 static Future<void> _removeCachedLocation() async {
   final prefs = await SharedPreferences.getInstance();
   for (final key in _cacheKeys) {
     if (!await prefs.remove(key)) {
       throw StateError('Location cache removal was not confirmed.');
     }
   }
 }

 Future<(Position?, String?)> getThrottledLocation({bool force = false}) async {
 final cacheGeneration = _cacheGeneration;
 try {
 await _cacheClear;
 final prefs = await SharedPreferences.getInstance();
 if (cacheGeneration != _cacheGeneration) return (null, null);
 final lastUpdateStr = prefs.getString('last_location_update');
 final lastLat = prefs.getDouble('last_lat') ?? 0.0;
 final lastLng = prefs.getDouble('last_lng') ?? 0.0;

 final now = DateTime.now();
 
 final lastUpdate = DateTime.tryParse(lastUpdateStr ?? '');
 bool timeThresholdMet = force || lastUpdate == null || lastUpdate.isAfter(now) ||
 now.difference(lastUpdate).inHours >= 24;

 LocationPermission permission = await Geolocator.checkPermission();
 if (permission == LocationPermission.denied) {
   if (!force) {
     final cachedGov = prefs.getString('last_resolved_governorate');
     return (null, cachedGov);
   }
   permission = await Geolocator.requestPermission();
   if (permission == LocationPermission.denied) return (null, null);
 }
 if (permission == LocationPermission.deniedForever) {
   final cachedGov = prefs.getString('last_resolved_governorate');
   return (null, cachedGov);
 }

 // Security Guard: Jailbreak and Mock Location Detection with safety timeouts
 try {
 final bool isJailBroken = await SafeDevice.isJailBroken.timeout(
 const Duration(seconds: 2),
 onTimeout: () {
 VSPLogger.w(" SafeDevice jailbreak check timed out. Defaulting to safe state.");
 return false;
 },
 );
 final bool isMockLocation = await SafeDevice.isMockLocation.timeout(
 const Duration(seconds: 2),
 onTimeout: () {
 VSPLogger.w(" SafeDevice mock location check timed out. Defaulting to safe state.");
 return false;
 },
 );
 if (isJailBroken || isMockLocation) {
 VSPLogger.w(" Device Security Alert: Jailbroken=$isJailBroken, MockLocation=$isMockLocation");
 return (null, "mock_location_detected");
 }
 } catch (e) {
 VSPLogger.e("Error performing safe device checks: $e");
 return (null, null);
 }

 // Get Position safely with high accuracy GPS for reliable governorate resolution
 Position? position;
 try {
 position = await Geolocator.getCurrentPosition(
 locationSettings: const LocationSettings(
 accuracy: LocationAccuracy.high,
 timeLimit: Duration(seconds: 8),
 ),
 );
 } catch (e) {
 VSPLogger.w("High accuracy GPS fetch timed out or unavailable, falling back to last known: $e");
 try {
 position = await Geolocator.getLastKnownPosition();
 } catch (_) {}
 }

 if (cacheGeneration != _cacheGeneration) return (null, null);
 if (position == null) {
 final cachedGov = prefs.getString('last_resolved_governorate');
 return (null, cachedGov);
 }

 double distanceInMeters = Geolocator.distanceBetween(
 lastLat, lastLng, position.latitude, position.longitude
 );

 if (force || timeThresholdMet || distanceInMeters > 5000) {
 VSPLogger.i(" GPS Optimized: Threshold met. Fetching placemark...");
 
 List<Placemark> placemarks = [];
 try {
 placemarks = await placemarkFromCoordinates(
 position.latitude, 
 position.longitude,
 ).timeout(const Duration(seconds: 4));
 } catch (e) {
 VSPLogger.w("Geocoding lookup failed: $e");
 }

 final rawName = placemarks.isNotEmpty
 ? (placemarks.first.administrativeArea ??
 placemarks.first.subAdministrativeArea ??
 placemarks.first.locality)
 : null;

 final newGov = EgyptGovernorates.resolveGovernorateWithCoordinates(
 lat: position.latitude,
 lng: position.longitude,
 rawGeocodeName: rawName,
 );
 
 if (cacheGeneration != _cacheGeneration) return (null, null);
 await prefs.setString('last_location_update', now.toIso8601String());
 if (cacheGeneration != _cacheGeneration) return (null, null);
 await prefs.setDouble('last_lat', position.latitude);
 if (cacheGeneration != _cacheGeneration) return (null, null);
 await prefs.setDouble('last_lng', position.longitude);
 if (cacheGeneration != _cacheGeneration) return (null, null);
 await prefs.setString('last_resolved_governorate', newGov);

 return (position, newGov);
 } else {
 VSPLogger.i(" GPS Optimized: Using cached location (Throttled)");
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



