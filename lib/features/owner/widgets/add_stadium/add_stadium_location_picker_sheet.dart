import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';

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

class AddStadiumLocationPickerSheet {
  static Future<LocationResult?> show(
    BuildContext context, {
    double? initialLat,
    double? initialLng,
  }) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    LatLng initialLocation = LatLng(initialLat ?? 30.0444, initialLng ?? 31.2357); // Cairo fallback

    // Attempt GPS position if no coordinates passed
    if (initialLat == null || initialLng == null) {
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
            initialLocation = LatLng(position.latitude, position.longitude);
          }
        }
      } catch (e) {
        VSPLogger.w('Could not fetch location for map start: $e');
      }
    }

    if (!context.mounted) return null;

    LatLng selectedCoords = initialLocation;
    final MapController mapController = MapController();
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    Future<List<Map<String, dynamic>>> searchLocation(String query, String langCode) async {
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

    Future<void> performSearch(String query, StateSetter setSheetState) async {
      if (query.trim().isEmpty) return;
      setSheetState(() {
        isSearching = true;
      });
      final results = await searchLocation(query, isArabic ? 'ar' : 'en');
      setSheetState(() {
        searchResults = results;
        isSearching = false;
      });
    }

    Future<LocationResult> resolveCoordinates(double lat, double lng) async {
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

    LocationResult? finalResult;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext builderContext, StateSetter setSheetState) {
            return Container(
              height: MediaQuery.of(builderContext).size.height * 0.85,
              decoration: const BoxDecoration(
                color: VSPColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: initialLocation,
                        initialZoom: 15.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                        onPositionChanged: (position, hasGesture) {
                          selectedCoords = position.center;
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.vsp.app',
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        transform: Matrix4.translationValues(0, -20, 0),
                        child: const Icon(
                          Iconsax.location_copy,
                          color: VSPColors.accent,
                          size: 48,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              offset: Offset(0, 4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Floating Search Overlay
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: VSPColors.surface.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              border: Border.all(color: VSPColors.divider),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Iconsax.search_normal_copy, color: VSPColors.accent, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: searchController,
                                    textInputAction: TextInputAction.search,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: isArabic
                                          ? 'ابحث عن منطقة، شارع أو مدينة في مصر...'
                                          : 'Search area, street or city in Egypt...',
                                      hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                                    ),
                                    onSubmitted: (val) => performSearch(val, setSheetState),
                                  ),
                                ),
                                if (isSearching)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                                  )
                                else if (searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 18),
                                    onPressed: () {
                                      searchController.clear();
                                      setSheetState(() {
                                        searchResults = [];
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                          if (searchResults.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                color: VSPColors.surface.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(VSPRadius.md),
                                border: Border.all(color: VSPColors.divider),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: searchResults.length,
                                separatorBuilder: (context, index) => const Divider(color: VSPColors.divider, height: 1),
                                itemBuilder: (context, index) {
                                  final result = searchResults[index];
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 18),
                                    title: Text(
                                      result['display_name'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                    onTap: () {
                                      final target = LatLng(result['lat'], result['lon']);
                                      selectedCoords = target;
                                      mapController.move(target, 16.0);
                                      setSheetState(() {
                                        searchResults = [];
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: VSPColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: VSPColors.divider),
                        ),
                        child: IconButton(
                          icon: const Icon(Iconsax.close_circle_copy, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ),
                    ),

                    // Floating GPS button
                    Positioned(
                      bottom: MediaQuery.of(builderContext).padding.bottom + 109,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: VSPColors.surface.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          border: Border.all(color: VSPColors.divider),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Iconsax.gps_copy, color: VSPColors.accent, size: 24),
                          onPressed: () async {
                            setSheetState(() {
                              isSearching = true;
                            });
                            try {
                              final position = await Geolocator.getCurrentPosition(
                                locationSettings: const LocationSettings(
                                  accuracy: LocationAccuracy.high,
                                  timeLimit: Duration(seconds: 5),
                                ),
                              );
                              final target = LatLng(position.latitude, position.longitude);
                              selectedCoords = target;
                              mapController.move(target, 16.0);
                            } catch (e) {
                              if (context.mounted) {
                                VSPFeedback.showError(context, 'Could not fetch current GPS location');
                              }
                            } finally {
                              setSheetState(() {
                                isSearching = false;
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: MediaQuery.of(builderContext).padding.bottom + 16,
                      left: 16,
                      right: 16,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          final res = await resolveCoordinates(selectedCoords.latitude, selectedCoords.longitude);
                          finalResult = res;
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(VSPRadius.md),
                          ),
                          elevation: 8,
                        ),
                        child: Text(
                          isArabic ? 'تأكيد الموقع' : 'Confirm Location',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return finalResult;
  }
}
