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

  /// Approximate center coordinates for Egyptian governorates used in offline/manual fallback
  static const Map<String, LatLng> governorateCoordinates = {
    'Cairo': LatLng(30.0444, 31.2357),
    'Giza': LatLng(30.0131, 31.2089),
    'Alexandria': LatLng(31.2001, 29.9187),
    'Dakahlia': LatLng(31.0409, 31.3785),
    'Red Sea': LatLng(27.2579, 33.8116),
    'Beheira': LatLng(31.0364, 30.4689),
    'Faiyum': LatLng(29.3084, 30.8428),
    'Gharbia': LatLng(30.7865, 31.0004),
    'Ismailia': LatLng(30.5965, 32.2715),
    'Monufia': LatLng(30.5972, 30.9876),
    'Qalyubia': LatLng(30.3292, 31.2168),
    'Sharqia': LatLng(30.5765, 31.5041),
    'Suez': LatLng(29.9668, 32.5498),
    'Aswan': LatLng(24.0889, 32.8998),
    'Asyut': LatLng(27.1809, 31.1837),
    'Beni Suef': LatLng(29.0661, 31.0994),
    'Port Said': LatLng(31.2653, 32.3019),
    'Damietta': LatLng(31.4175, 31.8144),
    'Kafr El Sheikh': LatLng(31.1107, 30.9388),
    'Matrouh': LatLng(31.3543, 27.2373),
    'Minya': LatLng(28.0871, 30.7618),
    'Qena': LatLng(26.1551, 32.7160),
    'Sohag': LatLng(26.5569, 31.6948),
    'South Sinai': LatLng(28.9585, 34.0306),
    'North Sinai': LatLng(30.6085, 33.6176),
    'Luxor': LatLng(25.6872, 32.6396),
    'New Valley': LatLng(25.4514, 30.5463),
  };

  /// Returns center coordinates for a governorate name or Cairo as fallback
  static LatLng getCoordinatesForGovernorate(String? governorate) {
    if (governorate == null || governorate.isEmpty) return cairoFallback;
    return governorateCoordinates[governorate] ?? cairoFallback;
  }

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
            final coords = getCoordinatesForGovernorate(enName);
            results.add({
              'display_name': displayName,
              'governorate': enName,
              'lat': coords.latitude,
              'lon': coords.longitude,
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
