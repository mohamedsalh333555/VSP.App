import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/services/logger_service.dart';
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
    final LatLng initialLocation = LatLng(initialLat ?? 30.0444, initialLng ?? 31.2357); // Cairo fallback

    LatLng selectedCoords = initialLocation;
    final MapController mapController = MapController();
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;
    bool isResolving = false;
    bool hasTriggeredGps = false;

    Future<void> performSearch(String query, StateSetter setSheetState) async {
      if (query.trim().isEmpty) return;
      setSheetState(() => isSearching = true);
      final results = await StadiumLocationGeocoder.searchLocation(query, isArabic ? 'ar' : 'en');
      setSheetState(() {
        searchResults = results;
        isSearching = false;
      });
    }

    return await showModalBottomSheet<LocationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext builderContext, StateSetter setSheetState) {
            // Trigger GPS centering in background without blocking opening
            if (!hasTriggeredGps && initialLat == null && initialLng == null) {
              hasTriggeredGps = true;
              StadiumLocationGeocoder.getCurrentGpsPosition().then((gps) {
                if (gps != null && builderContext.mounted) {
                  selectedCoords = gps;
                  mapController.move(gps, 15.0);
                }
              });
            }
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

                    // Fallback to manual entry button
                    Positioned(
                      bottom: MediaQuery.of(builderContext).padding.bottom + 76,
                      left: 16,
                      right: 16,
                        child: InkWell(
                          onTap: () async {
                            final manualRes = await showManualAddressDialog(context);
                            if (manualRes != null && sheetContext.mounted) {
                              Navigator.pop(sheetContext, manualRes);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: VSPColors.surface.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(VSPRadius.sm),
                              border: Border.all(color: VSPColors.divider),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Iconsax.edit_copy, size: 14, color: VSPColors.accent),
                                const SizedBox(width: 6),
                                Text(
                                  isArabic ? 'تعذر تحميل الخريطة؟ اضغط للإدخال اليدوي' : 'Map not loading? Tap for manual entry',
                                  style: const TextStyle(
                                    color: VSPColors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      bottom: MediaQuery.of(builderContext).padding.bottom + 16,
                      left: 16,
                      right: 16,
                      child: ElevatedButton(
                        onPressed: isResolving
                            ? null
                            : () async {
                                setSheetState(() => isResolving = true);
                                try {
                                  final res = await StadiumLocationGeocoder.resolveCoordinates(
                                    selectedCoords.latitude,
                                    selectedCoords.longitude,
                                  );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext, res);
                                  }
                                } catch (e) {
                                  VSPLogger.w('Failed to resolve coordinates: $e');
                                  if (sheetContext.mounted) {
                                    final fallback = LocationResult(
                                      latitude: selectedCoords.latitude,
                                      longitude: selectedCoords.longitude,
                                      address: '${selectedCoords.latitude.toStringAsFixed(5)}, ${selectedCoords.longitude.toStringAsFixed(5)}',
                                    );
                                    Navigator.pop(sheetContext, fallback);
                                  }
                                }
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
                        child: isResolving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
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
  }

  /// Displays an offline/manual address entry modal sheet allowing the owner to enter the address without map tiles.
  static Future<LocationResult?> showManualAddressDialog(
    BuildContext context, {
    String? initialGovernorate,
    String? initialAddress,
  }) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String selectedGovernorate = (initialGovernorate != null && EgyptGovernorates.allGovernorates.contains(initialGovernorate))
        ? initialGovernorate
        : 'Cairo';
    final TextEditingController addressController = TextEditingController(text: initialAddress ?? '');
    String? addressError;

    return await showModalBottomSheet<LocationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: VSPColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: VSPColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: VSPColors.accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isArabic ? 'إدخال موقع الملعب يدوياً' : 'Enter Stadium Location Manually',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 20),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Information Notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.info_circle_copy, color: VSPColors.textSecondary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'يمكنك كتابة العنوان الآن والمتابعة، مع إمكانية تعديل وتحديد الإحداثيات الدقيقة على الخريطة لاحقاً من تعديل الملعب.'
                                  : 'You can type your address now and proceed. Precise GPS coordinates can be updated anytime later in stadium settings.',
                              style: const TextStyle(
                                color: VSPColors.textSecondary,
                                fontSize: 11.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Governorate Dropdown
                    Text(
                      isArabic ? 'المحافظة' : 'Governorate',
                      style: Theme.of(ctx).textTheme.labelMedium?.copyWith(color: VSPColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.input),
                        border: Border.all(color: VSPColors.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedGovernorate,
                          isExpanded: true,
                          dropdownColor: VSPColors.surface,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.textSecondary, size: 18),
                          items: EgyptGovernorates.allGovernorates.map((gov) {
                            final arName = EgyptGovernorates.governorateToArabic[gov] ?? gov;
                            return DropdownMenuItem<String>(
                              value: gov,
                              child: Text(isArabic ? arName : gov),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedGovernorate = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Detailed Address Text Field
                    Text(
                      isArabic ? 'العنوان بالتفصيل' : 'Detailed Address',
                      style: Theme.of(ctx).textTheme.labelMedium?.copyWith(color: VSPColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: isArabic
                            ? 'اسم الشارع، المنطقة، أو أقرب علامة مميزة...'
                            : 'Street name, district, or nearest landmark...',
                        hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                        filled: true,
                        fillColor: VSPColors.surface,
                        errorText: addressError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(VSPRadius.input),
                          borderSide: const BorderSide(color: VSPColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(VSPRadius.input),
                          borderSide: const BorderSide(color: VSPColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(VSPRadius.input),
                          borderSide: const BorderSide(color: VSPColors.accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Confirm Button
                    ElevatedButton(
                      onPressed: () {
                        final trimmed = addressController.text.trim();
                        if (trimmed.isEmpty) {
                          setModalState(() {
                            addressError = isArabic ? 'يرجى إدخال عنوان الملعب' : 'Please enter stadium address';
                          });
                          return;
                        }
                        final coords = StadiumLocationGeocoder.getCoordinatesForGovernorate(selectedGovernorate);
                        final govAr = EgyptGovernorates.governorateToArabic[selectedGovernorate] ?? selectedGovernorate;
                        final fullAddress = isArabic ? '$govAr، $trimmed' : '$selectedGovernorate, $trimmed';

                        final result = LocationResult(
                          latitude: coords.latitude,
                          longitude: coords.longitude,
                          address: fullAddress,
                          governorate: selectedGovernorate,
                        );
                        Navigator.pop(modalContext, result);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VSPColors.accent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                        ),
                      ),
                      child: Text(
                        isArabic ? 'تأكيد العنوان والمتابعة' : 'Confirm Address & Proceed',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
  }
}
