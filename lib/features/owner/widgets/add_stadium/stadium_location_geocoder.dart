import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/services/logger_service.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String address;
  final String? governorate;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.governorate,
  });
}

/// Service handling location searches, GPS fetching, and geocoding resolution for stadium creation.
class StadiumLocationGeocoder {
  static const LatLng cairoFallback = LatLng(30.0444, 31.2357);

  /// Attempts to fetch the device's current GPS position with permission checks and timeout.
  static Future<LatLng?> getCurrentGpsPosition() async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
          return LatLng(position.latitude, position.longitude);
        }
      }
    } catch (e) {
      VSPLogger.w('Could not fetch location for map start: $e');
    }
    return null;
  }

  /// Searches for matching locations across Egypt governorates, native geocoder, and Nominatim.
  static Future<List<Map<String, dynamic>>> searchLocation(String query, String langCode) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    final List<Map<String, dynamic>> results = [];
    final Set<String> seen = {};

    // 1. Prioritize local search matches from EgyptGovernorates
    try {
      final isAr = langCode == 'ar';
      EgyptGovernorates.governorateToArabic.forEach((enName, arName) {
        if (enName.toLowerCase().contains(trimmedQuery.toLowerCase()) ||
            arName.contains(trimmedQuery)) {
          final displayName = isAr ? 'محافظة $arName - مصر' : '$enName Governorate, Egypt';
          if (!seen.contains(displayName)) {
            seen.add(displayName);
            results.add({
              'display_name': displayName,
              'governorate': enName,
              'lat': 30.0444,
              'lon': 31.2357,
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Local governorate search notice: $e');
    }

    // 2. Native device geocoding first
    try {
      final locations = await locationFromAddress('$trimmedQuery, Egypt')
          .timeout(const Duration(seconds: 5));
      if (locations.isNotEmpty) {
        for (var loc in locations.take(3)) {
          final key = '${loc.latitude},${loc.longitude}';
          if (!seen.contains(key)) {
            seen.add(key);
            results.add({
              'display_name': '$trimmedQuery, مصر',
              'lat': loc.latitude,
              'lon': loc.longitude,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Native geocoding notice: $e');
    }

    // 3. Fallback to OpenStreetMap Nominatim with 5s timeout and error handling
    if (results.isEmpty) {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(trimmedQuery)}&countrycodes=eg&accept-language=$langCode&limit=5',
        );
        final response = await http.get(url, headers: {
          'User-Agent': 'VSP_Application/1.0',
        }).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          for (var item in data) {
            final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
            final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
            final name = item['display_name'] ?? '';
            final key = '$lat,$lon';
            if (!seen.contains(key) && lat != 0.0 && lon != 0.0) {
              seen.add(key);
              results.add({
                'display_name': name,
                'lat': lat,
                'lon': lon,
              });
            }
          }
        }
      } catch (e) {
        VSPLogger.e('Error searching location via Nominatim', e);
      }
    }

    return results;
  }

  /// Reverse-geocodes coordinate pair into structured readable address and Egyptian governorate.
  static Future<LocationResult> resolveCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 5));
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final subLocality = place.subLocality ?? '';
        final locality = place.locality ?? '';
        final administrativeArea = place.administrativeArea ?? '';

        final readableAddress = EgyptGovernorates.formatSmartLocation(
          subLocality: subLocality,
          locality: locality,
          subAdministrativeArea: place.subAdministrativeArea,
          administrativeArea: administrativeArea,
          rawAddress: place.name,
        );

        final rawName = place.administrativeArea ?? place.subAdministrativeArea ?? place.locality;
        final resolvedGov = EgyptGovernorates.resolveGoogleName(rawName);

        return LocationResult(
          latitude: lat,
          longitude: lng,
          address: readableAddress,
          governorate: resolvedGov,
        );
      }
    } catch (e) {
      VSPLogger.e('Geocoding error', e);
    }

    return LocationResult(
      latitude: lat,
      longitude: lng,
      address: 'Lat: $lat, Long: $lng',
    );
  }
}
