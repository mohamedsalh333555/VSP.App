import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import 'stadium_location_geocoder.dart';

export 'stadium_location_geocoder.dart' show LocationResult, StadiumLocationGeocoder;

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
      final gps = await StadiumLocationGeocoder.getCurrentGpsPosition();
      if (gps != null) initialLocation = gps;
    }

    if (!context.mounted) return null;

    LatLng selectedCoords = initialLocation;
    final MapController mapController = MapController();
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    Future<void> performSearch(String query, StateSetter setSheetState) async {
      if (query.trim().isEmpty) return;
      setSheetState(() => isSearching = true);
      final results = await StadiumLocationGeocoder.searchLocation(query, isArabic ? 'ar' : 'en');
      setSheetState(() {
        searchResults = results;
        isSearching = false;
      });
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
                            setSheetState(() => isSearching = true);
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
                              setSheetState(() => isSearching = false);
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
                          final res = await StadiumLocationGeocoder.resolveCoordinates(
                            selectedCoords.latitude,
                            selectedCoords.longitude,
                          );
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
