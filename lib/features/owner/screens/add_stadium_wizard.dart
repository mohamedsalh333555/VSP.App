import '../../../l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import 'package:provider/provider.dart';
import '../../../shared/widgets/vsp_upload_widgets.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/constants/egypt_governorates.dart';
import 'package:geocoding/geocoding.dart';
import '../../../shared/widgets/custom_text_field.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddStadiumWizard extends StatefulWidget {
  final String? stadiumId;
  const AddStadiumWizard({super.key, this.stadiumId});

  @override
  State<AddStadiumWizard> createState() => _AddStadiumWizardState();
}

class _AddStadiumWizardState extends State<AddStadiumWizard> {
  final _ballPriceController = TextEditingController();
  final _depositController = TextEditingController();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoadingData = false;

  // Form Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _locationController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _seatsController = TextEditingController();
  final _notesController = TextEditingController();
  bool? _hasBall;

  // State variables for features
  bool? _cafeteria;
  bool? _garage;
  bool? _changingRoom;
  String? _selectedSportType;
  String? _selectedFloorType;
  String? _selectedBathOption;

  // Appointment state
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSplitShift = false;
  List<Map<String, TimeOfDay?>> _breakTimes = [];

  // Step 3: Stadium Images
  final List<Map<String, dynamic>> _images = [];
  final bool _isUploading = false;
  bool _isLocationLoading = false;
  bool _isSaving = false;
  String? _governorate; // ✅ Extracted via Geocoding for filtering
  bool _requireDeposit = false;

  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  final StadiumRepository _databaseService = StadiumRepository();

  bool get _isSplitShiftValid {
    if (!_isSplitShift) return true;
    if (_startTime == null || _endTime == null) return true;

    int t(TimeOfDay time) => time.hour * 60 + time.minute;
    final start = t(_startTime!);
    final end = t(_endTime!);
    int normEnd = (end <= start) ? end + (24 * 60) : end;

    for (var breakEntry in _breakTimes) {
      final bStart = breakEntry['start'];
      final bEnd = breakEntry['end'];
      if (bStart == null || bEnd == null) continue;

      final btStart = t(bStart);
      final btEnd = t(bEnd);

      int normBStart = (btStart < start && end <= start) ? btStart + (24 * 60) : btStart;
      int normBEnd = (btEnd < start && end <= start) ? btEnd + (24 * 60) : btEnd;

      if (!(normBStart >= start && normBEnd <= normEnd && normBStart < normBEnd)) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (widget.stadiumId != null) {
      _loadStadiumData();
    }
  }

  Future<void> _loadStadiumData() async {
    setState(() => _isLoadingData = true);
    try {
      final data = await _databaseService.getStadiumSnapshot(widget.stadiumId!);
      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _locationController.text = data['location'] ?? '';
        _priceController.text = (data['pricePerHour'] ?? 0).toString();
        _capacityController.text = (data['seatsCapacity'] ?? data['players_per_team'] ?? 0).toString();
        final depositVal = data['deposit_amount'] ?? 0.0;
        _depositController.text = depositVal == 0.0 ? '' : depositVal.toString();
        _requireDeposit = data['needs_deposit'] ?? data['needsDeposit'] ?? (depositVal > 0.0);
        
        final features = data['features'] as Map<String, dynamic>? ?? {};
        _selectedFloorType = features['floorType'];
        _selectedSportType = features['sportType'];
        _selectedBathOption = features['bathOption'];
        _cafeteria = features['cafeteria'];
        _garage = features['garage'];
        _changingRoom = features['changingRoom'];
        _seatsController.text = features['seats'] ?? '';
        _lengthController.text = features['length'] ?? '';
        _widthController.text = features['width'] ?? '';
        _hasBall = features['hasBall'] ?? false;
        _ballPriceController.text = (features['ballPrice'] ?? 0).toString();
        
        final workingHours = features['workingHours'] as Map<String, dynamic>?;
        if (workingHours != null) {
          _startTime = _parseTime(workingHours['start']);
          _endTime = _parseTime(workingHours['end']);
        }
        
        _isSplitShift = features['isSplitShift'] ?? false;
        _breakTimes = [];
        if (features['breakTimes'] != null) {
          final list = features['breakTimes'] as List;
          for (var item in list) {
            if (item is Map) {
              _breakTimes.add({
                'start': _parseTime(item['start']?.toString()),
                'end': _parseTime(item['end']?.toString()),
              });
            }
          }
        }
        if (_breakTimes.isEmpty && features['breakTime'] != null) {
          final breakTime = features['breakTime'] as Map<String, dynamic>;
          _breakTimes.add({
            'start': _parseTime(breakTime['start']?.toString()),
            'end': _parseTime(breakTime['end']?.toString()),
          });
        }

        final allImages = List<String>.from(features['allImages'] ?? []);
        if (allImages.isEmpty && data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
           allImages.add(data['imageUrl']);
        }

        for (var url in allImages) {
          _images.add({'file': null, 'url': url, 'isUploading': false});
        }

        _notesController.text = data['notes'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading stadium data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.length != 2) return null;
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _locationController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _seatsController.dispose();
    _notesController.dispose();
    _pageController.dispose();
    _ballPriceController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  // --- Actions ---

  void _showError(String message) {
     VSPFeedback.showError(context, message);
  }



  Future<void> _resolveLocationAndAddress(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 5));
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final street = place.street ?? '';
        final subLocality = place.subLocality ?? '';
        final locality = place.locality ?? '';
        final administrativeArea = place.administrativeArea ?? '';

        final addressParts = [
          if (street.isNotEmpty && street != place.name) street,
          if (subLocality.isNotEmpty) subLocality,
          if (locality.isNotEmpty) locality,
          if (administrativeArea.isNotEmpty) administrativeArea,
        ];

        final readableAddress = addressParts.isNotEmpty ? addressParts.join(', ') : 'Lat: $lat, Long: $lng';

        setState(() {
          _locationController.text = readableAddress;
          final rawName = place.administrativeArea ?? place.subAdministrativeArea ?? place.locality;
          final resolved = EgyptGovernorates.resolveGoogleName(rawName);
          if (resolved != null) {
            _governorate = resolved;
          } else {
            _governorate = 'Cairo'; // Fallback
          }
          VSPLogger.i('📍 Address resolved to: $readableAddress, Governorate: $_governorate');
        });
      } else {
        setState(() {
          _locationController.text = 'Lat: $lat, Long: $lng';
          _governorate = 'Cairo'; // Fallback
        });
      }
    } catch (e) {
      VSPLogger.e('❌ Geocoding error', e);
      setState(() {
        _locationController.text = 'Lat: $lat, Long: $lng';
        _governorate = 'Cairo'; // Fallback
      });
    }
  }

  Future<List<Map<String, dynamic>>> _searchLocation(String query, String langCode) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&countrycodes=eg&accept-language=$langCode&limit=5'
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'VSP_Application/1.0',
      });
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) => {
          'display_name': item['display_name'] ?? '',
          'lat': double.tryParse(item['lat']?.toString() ?? '') ?? 0.0,
          'lon': double.tryParse(item['lon']?.toString() ?? '') ?? 0.0,
        }).toList().cast<Map<String, dynamic>>();
      }
    } catch (e) {
      VSPLogger.e('Error searching location', e);
    }
    return [];
  }

  Future<void> _openMapPicker() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    setState(() => _isLocationLoading = true);
    
    LatLng initialLocation = const LatLng(30.0444, 31.2357); // Cairo fallback
    
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          initialLocation = LatLng(position.latitude, position.longitude);
        }
      }
    } catch (e) {
      VSPLogger.w('Could not fetch location for map start: $e');
    } finally {
      setState(() => _isLocationLoading = false);
    }

    if (!mounted) return;

    LatLng selectedCoords = initialLocation;
    final MapController mapController = MapController();
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    Future<void> performSearch(String query, StateSetter setSheetState) async {
      if (query.trim().isEmpty) return;
      setSheetState(() {
        isSearching = true;
      });
      final results = await _searchLocation(query, isArabic ? 'ar' : 'en');
      setSheetState(() {
        searchResults = results;
        isSearching = false;
      });
    }

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
                        child: Icon(LucideIcons.mapPin,
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
                                Icon(LucideIcons.search, color: VSPColors.accent, size: 22),
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
                                    icon: Icon(LucideIcons.x, color: VSPColors.textSecondary, size: 18),
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
                                    leading: Icon(LucideIcons.mapPin, color: VSPColors.accent, size: 18),
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
                          icon: Icon(LucideIcons.x, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ),
                    ),
                    
                    // Floating GPS button
                    Positioned(
                      bottom: MediaQuery.of(builderContext).padding.bottom + 85,
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
                          icon: Icon(LucideIcons.locate, color: VSPColors.accent, size: 24),
                          onPressed: () async {
                            setSheetState(() {
                              isSearching = true;
                            });
                            try {
                              Position position = await Geolocator.getCurrentPosition(
                                desiredAccuracy: LocationAccuracy.high,
                                timeLimit: const Duration(seconds: 5),
                              );
                              final target = LatLng(position.latitude, position.longitude);
                              selectedCoords = target;
                              mapController.move(target, 16.0);
                            } catch (e) {
                              if (mounted) {
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
                          setState(() => _isLocationLoading = true);
                          await _resolveLocationAndAddress(selectedCoords.latitude, selectedCoords.longitude);
                          setState(() => _isLocationLoading = false);
                          if (mounted) {
                            VSPFeedback.showSuccess(
                              context,
                              isArabic ? 'تم تحديد موقع الملعب بنجاح! 📍' : 'Stadium location selected successfully! 📍',
                            );
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
  }

  Future<void> _selectTime(BuildContext context, bool isMainStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: VSPColors.accent,
              onPrimary: Colors.black,
              surface: VSPColors.surface,
              onSurface: VSPColors.textPrimary,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: VSPColors.surface,
              dialBackgroundColor: VSPColors.surfaceAlt,
              dayPeriodColor: WidgetStateColor.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? VSPColors.accent
                      : VSPColors.surfaceAlt),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? Colors.black
                      : VSPColors.textSecondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VSPRadius.xl),
              ),
            ),
          ),
          child: child!,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isMainStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _selectTimeForBreak(BuildContext context, int index, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: VSPColors.accent,
              onPrimary: Colors.black,
              surface: VSPColors.surface,
              onSurface: VSPColors.textPrimary,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: VSPColors.surface,
              dialBackgroundColor: VSPColors.surfaceAlt,
              dayPeriodColor: WidgetStateColor.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? VSPColors.accent
                      : VSPColors.surfaceAlt),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? Colors.black
                      : VSPColors.textSecondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VSPRadius.xl),
              ),
            ),
          ),
          child: child!,
        ),
      ),
    );
    if (picked != null && mounted) {
      int minutes = picked.minute;
      int roundedMinute;
      int hour = picked.hour;

      // تقريب الدقائق تلقائياً لأقرب 30 دقيقة (00 أو 30)
      if (minutes < 15) {
        roundedMinute = 0;
      } else if (minutes < 45) {
        roundedMinute = 30;
      } else {
        roundedMinute = 0;
        hour = (hour + 1) % 24; // الانتقال للساعة التالية
      }

      final roundedTime = TimeOfDay(hour: hour, minute: roundedMinute);

      setState(() {
        if (isStart) {
          _breakTimes[index]['start'] = roundedTime;
        } else {
          _breakTimes[index]['end'] = roundedTime;
        }
      });
    }
  }

  Future<void> _pickImage() async {
    Timer? progressTimer;
    final XFile? pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    final imageEntry = {'file': imageFile, 'url': null, 'isUploading': true, 'progress': 0};
    setState(() => _images.add(imageEntry));
    
    try {
      // Start simulated progress ticking
      progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted || imageEntry['isUploading'] != true) {
          timer.cancel();
          return;
        }
        setState(() {
          int current = imageEntry['progress'] as int? ?? 0;
          if (current < 95) {
            imageEntry['progress'] = current + 5;
          }
        });
      });

      // Upload
      final url = await _storageService.uploadFile(
        file: XFile(imageFile.path),
        bucket: 'stadium-images',
        path: 'stadiums/images/std_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      progressTimer.cancel();
      if (!mounted) return;
      if (url == null) {
        setState(() {
          _images.remove(imageEntry);
        });
        if (mounted) {
          VSPFeedback.showError(context, 'Failed to upload photo. Please check storage bucket.');
        }
        return;
      }
      setState(() {
        imageEntry['url'] = url;
        imageEntry['progress'] = 100;
        imageEntry['isUploading'] = false;
      });
    } catch (e) {
      progressTimer?.cancel();
      if (mounted) {
        setState(() {
          imageEntry['isUploading'] = false;
          _images.remove(imageEntry);
          VSPFeedback.showError(context, 'Upload failed');
        });
      }
    }
  }



  void _nextPage() {
    if (_currentStep == 0) {
      if (_nameController.text.isEmpty || _selectedSportType == null || _priceController.text.isEmpty || _startTime == null || _endTime == null) {
        _showError(AppLocalizations.of(context)!.basicInfoError);
        return;
      }

      // ── Split-Shift (Break Time) Validation ──
      if (_isSplitShift) {
        if (_breakTimes.isEmpty) {
          _showError("Please add at least one break time.");
          return;
        }

        for (var i = 0; i < _breakTimes.length; i++) {
          final bStart = _breakTimes[i]['start'];
          final bEnd = _breakTimes[i]['end'];
          if (bStart == null || bEnd == null) {
            _showError("Please set start and end times for Break ${i + 1}.");
            return;
          }

          int t(TimeOfDay time) => time.hour * 60 + time.minute;
          final start = t(_startTime!);
          final end = t(_endTime!);
          final bStartMin = t(bStart);
          final bEndMin = t(bEnd);

          int normEnd = (end <= start) ? end + (24 * 60) : end;
          int normBStart = (bStartMin < start && end <= start) ? bStartMin + (24 * 60) : bStartMin;
          int normBEnd = (bEndMin < start && end <= start) ? bEndMin + (24 * 60) : bEndMin;

          bool isBreakInHours = normBStart >= start && normBEnd <= normEnd && normBStart < normBEnd;

          if (!isBreakInHours) {
            _showError("Break ${i + 1} must be within opening hours (${_formatTime(_startTime, '')} - ${_formatTime(_endTime, '')}).");
            return;
          }
        }
      }
    } else if (_currentStep == 1) {
      if (_selectedBathOption == null || _cafeteria == null) {
        _showError(AppLocalizations.of(context)!.selectFeaturesError);
        return;
      }
      if (_hasBall == true) {
        final ballPrice = double.tryParse(_ballPriceController.text) ?? 0.0;
        if (ballPrice < 5.0) {
          _showError(AppLocalizations.of(context)!.ballPriceMinError);
          return;
        }
      }
      if (_requireDeposit) {
        final deposit = double.tryParse(_depositController.text.trim()) ?? 0.0;
        final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
        if (deposit <= 0) {
          _showError("Please set a valid deposit amount.");
          return;
        }
        if (deposit > (price * 0.5)) {
          _showError("Deposit amount cannot exceed 50% of the hourly price (${price * 0.5} EGP).");
          return;
        }
      }
    } else if (_currentStep == 2) {
      // Validate Images & Submit
      if (_images.isEmpty && (widget.stadiumId == null)) {
        _showError(AppLocalizations.of(context)!.uploadPhotoError);
        return;
      }
      _saveStadium(); // Submit immediately after images
      return;
    }

    if (_currentStep < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _saveStadium() async {
    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
    if (auth.userModel?.isBlocked == true) {
      VSPFeedback.showError(context, "Your account is blocked. You cannot save or submit stadium details.");
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uploadedUrls = _images.where((img) => img['url'] != null).map((img) => img['url'] as String).toList();
      
      // Get user from Provider for more stable reference
      final user = auth.firebaseUser;
      
      if (user == null) {
        _showError("Authentication lost. Please login again.");
        return;
      }

      final stadiumFeatures = {
        'sportType': _selectedSportType,
        'floorType': _selectedFloorType,
        'bathOption': _selectedBathOption,
        'cafeteria': _cafeteria,
        'garage': _garage,
        'changingRoom': _changingRoom,
        'seats': _seatsController.text.trim(),
        'length': _lengthController.text.trim(),
        'width': _widthController.text.trim(),
        'hasBall': _hasBall ?? false,
        'ballPrice': (_hasBall == true) ? (double.tryParse(_ballPriceController.text) ?? 0.0) : 0.0,
        'workingHours': {
          'start': _formatTime(_startTime, '08:00 AM'),
          'end': _formatTime(_endTime, '12:00 AM'),
        },
        'isSplitShift': _isSplitShift,
        'breakTimes': _isSplitShift 
            ? _breakTimes.map((bt) => {
                'start': _formatTime(bt['start'], ''),
                'end': _formatTime(bt['end'], ''),
              }).toList()
            : [],
        'breakTime': (_isSplitShift && _breakTimes.isNotEmpty) 
            ? {
                'start': _formatTime(_breakTimes.first['start'], ''),
                'end': _formatTime(_breakTimes.first['end'], ''),
              } 
            : null,
        'allImages': uploadedUrls,
      };

      if (widget.stadiumId != null) {
          // Update Logic
          await _databaseService.updateStadium(widget.stadiumId!, {
            'name': _nameController.text.trim(),
            'location': _locationController.text.trim(),
            'governorate': _governorate, // ✅ Added for filtering
            'pricePerHour': double.parse(_priceController.text.trim()),
            'players_per_team': int.tryParse(_capacityController.text.trim()) ?? 5,
            'total_field_capacity': (int.tryParse(_capacityController.text.trim()) ?? 5) * 2,
            'deposit_amount': _requireDeposit ? (double.tryParse(_depositController.text.trim()) ?? 0.0) : 0.0,
            'needs_deposit': _requireDeposit,
            'imageUrl': uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
            'notes': _notesController.text.trim(),
            'features': stadiumFeatures,
          });
      } else {
          // Create Logic
          final stadiumId = await _databaseService.createStadium(
            name: _nameController.text.trim(),
            location: _locationController.text.trim(),
            governorate: _governorate, // ✅ Added for filtering
            pricePerHour: double.parse(_priceController.text.trim()),
            seatsCapacity: int.tryParse(_capacityController.text.trim()) ?? 5,
            depositAmount: _requireDeposit ? (double.tryParse(_depositController.text.trim()) ?? 0.0) : 0.0,
            needsDeposit: _requireDeposit,
            imageUrl: uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
            ownerId: user.uid,
            notes: _notesController.text.trim().isEmpty 
              ? "We ensure a professional environment. Please arrive on time. Respect the facility and equipment. Late arrival may result in reduced playing time."
              : _notesController.text.trim(),
            features: stadiumFeatures,
          );

          if (stadiumId == null) {
            _showError("Failed to create stadium. Please check your data or permissions.");
            return;
          }
          // ✅ IMMEDIATELY set hasStadium flag so app navigation knows
          await auth.updateProfile({'hasStadium': true});
      }
      
      if (mounted) {
        VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.stadiumSubmitSuccess);
        Navigator.pop(context); // Return to FacilityOnboardingScreen — StreamBuilder will auto-refresh
      }
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, AppLocalizations.of(context)!.stadiumSaveFailed);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // use VSPFeedback directly instead of _showError helper

  String _formatTime(TimeOfDay? time, String defaultText) {
    if (time == null) return defaultText;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        leading: IconButton(icon: Icon(LucideIcons.arrowLeft, color: VSPColors.textPrimary), onPressed: _previousPage),
        title: Text(AppLocalizations.of(context)!.addStadium, style: Theme.of(context).textTheme.displaySmall),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildStepIndicator(),
            const SizedBox(height: 20),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Details(),
                  _buildStep2Features(),
                  _buildStep3Images(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final labels = [
      isArabic ? 'البيانات' : 'Details',
      isArabic ? 'الخدمات' : 'Features',
      isArabic ? 'الصور' : 'Photos',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Stack(
        children: [
          // Background Connecting Lines
          Positioned(
            left: 28 / 2 + 12, // Half circle diameter + horizontal padding
            right: 28 / 2 + 12,
            top: 28 / 2 - 1, // Centered vertically on the circles
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    color: _currentStep >= 1 ? VSPColors.accent : VSPColors.divider,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: _currentStep >= 2 ? VSPColors.accent : VSPColors.divider,
                  ),
                ),
              ],
            ),
          ),
          // Stepper Circles and Text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final isActive = i <= _currentStep;
              final isCurrent = i == _currentStep;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? VSPColors.accent : VSPColors.surface,
                      border: Border.all(
                        color: isActive ? VSPColors.accent : VSPColors.divider,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: i < _currentStep
                          ? Icon(LucideIcons.check, color: Colors.black, size: 16)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: isActive ? Colors.black : VSPColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isCurrent ? VSPColors.accent : VSPColors.textSecondary,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 9,
                        ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- Steps ---

  Widget _buildStep1Details() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
      padding: EdgeInsets.only(
        left: VSPSpacing.md,
        right: VSPSpacing.md,
        top: VSPSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + VSPSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(AppLocalizations.of(context)!.location, AppLocalizations.of(context)!.tapToFetch, controller: _locationController, readOnly: true),
          const SizedBox(height: 8),
          if (widget.stadiumId != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.lock, color: VSPColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'الموقع الجغرافي للملعب ثابت ولا يمكن تعديله بعد التسجيل.'
                          : 'The geographical location of the stadium is fixed and cannot be changed.',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            _isLocationLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(color: VSPColors.accent),
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openMapPicker,
                      icon: Icon(LucideIcons.map, color: Colors.black),
                      label: Text(
                        isArabic ? 'تحديد موقع الملعب على الخريطة 🗺️' : 'Select Stadium Location on Map 🗺️',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VSPColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
          ],
          _buildTextField(AppLocalizations.of(context)!.stadiumName, 'Ex: Anfield', controller: _nameController, maxLength: 50),
          const SizedBox(height: 16),
          _buildGovernorateDropdown(),
          const SizedBox(height: 16),
          _buildSportDropdown(),
          const SizedBox(height: 16),
          _buildTextField(
            AppLocalizations.of(context)!.pricePerHour, 
            '0.0', 
            controller: _priceController, 
            maxLength: 7,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            AppLocalizations.of(context)!.playersTeam, 
            '5', 
            controller: _capacityController,
            maxLength: 2,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          
          Text(AppLocalizations.of(context)!.workingHours, style: const TextStyle(color: VSPColors.textSecondary)),
          Row(children: [
            Expanded(child: GestureDetector(onTap: () => _selectTime(context, true), child: _buildTimeBox(_formatTime(_startTime, AppLocalizations.of(context)!.start), isSelected: _startTime != null))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(onTap: () => _selectTime(context, false), child: _buildTimeBox(_formatTime(_endTime, AppLocalizations.of(context)!.end), isSelected: _endTime != null))),
          ]),
          if (_endTime != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, color: VSPColors.accent, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                      final closingTime = TimeOfDay(
                        hour: (_endTime!.hour + 1) % 24, 
                        minute: _endTime!.minute,
                      );
                      final selectedEndStr = _formatTime(_endTime, '');
                      final realCloseStr = _formatTime(closingTime, '');
                      
                      return Text(
                        isArabic 
                            ? "ملاحظة: اختيار وقت الانتهاء ($selectedEndStr) يعني أن آخر حجز سيبدأ في هذا الوقت، وسيغلق الملعب فعلياً الساعة ($realCloseStr)."
                            : "Note: Selecting ($selectedEndStr) means the last booking starts at this time. The pitch will actually close at ($realCloseStr).",
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, height: 1.4),
                      );
                    }
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 12),
          // Break Time Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.setDailyBreak, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary)),
              Switch.adaptive(
                value: _isSplitShift,
                onChanged: (val) {
                  setState(() {
                    _isSplitShift = val;
                    if (_isSplitShift && _breakTimes.isEmpty) {
                      _breakTimes.add({'start': null, 'end': null});
                    }
                  });
                },
                activeColor: VSPColors.accent,
              ),
            ],
          ),
          
          if (_isSplitShift) ...[
            const SizedBox(height: 8),
            ..._breakTimes.asMap().entries.map((entry) {
              final index = entry.key;
              final bt = entry.value;
              final bStart = bt['start'];
              final bEnd = bt['end'];
              final isArabic = Localizations.localeOf(context).languageCode == 'ar';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic ? 'فترة راحة ${index + 1}' : 'Break ${index + 1}',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      if (_breakTimes.length > 1)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(LucideIcons.trash2, color: VSPColors.error, size: 20),
                          onPressed: () {
                            setState(() {
                              _breakTimes.removeAt(index);
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: GestureDetector(onTap: () => _selectTimeForBreak(context, index, true), child: _buildTimeBox(_formatTime(bStart, AppLocalizations.of(context)!.breakStart), isSelected: bStart != null))),
                    const SizedBox(width: 10),
                    Expanded(child: GestureDetector(onTap: () => _selectTimeForBreak(context, index, false), child: _buildTimeBox(_formatTime(bEnd, AppLocalizations.of(context)!.breakEnd), isSelected: bEnd != null))),
                  ]),
                ],
              );
            }),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _breakTimes.add({'start': null, 'end': null});
                  });
                },
                icon: Icon(LucideIcons.plus, color: VSPColors.accent, size: 18),
                label: const Text('+ Add Another Break', style: TextStyle(color: VSPColors.accent, fontSize: 13)),
              ),
            ),
            if (!_isSplitShiftValid) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: VSPColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                  border: Border.all(color: VSPColors.error.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, color: VSPColors.error, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Break hours must fall strictly inside the opening and closing hours!',
                        style: TextStyle(color: VSPColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildTextField('Length', 'm', controller: _lengthController)),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField('Width', 'm', controller: _widthController)),
          ]),
          
          const SizedBox(height: 16),
          _buildTextField(
            'Notes', 
            'Ex: We ensure a professional environment. Please arrive on time...', 
            controller: _notesController, 
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'Punctuality',
                'Cleanliness',
                'No Smoking',
                'Bring your own ball'
              ].map((template) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(template, style: const TextStyle(fontSize: 12)),
                  backgroundColor: VSPColors.surface,
                  labelStyle: const TextStyle(color: VSPColors.accent),
                  onPressed: () {
                    final currentText = _notesController.text;
                    final prefix = currentText.isEmpty ? '' : '$currentText\n';
                    setState(() => _notesController.text = '$prefix• $template');
                  },
                ),
              )).toList(),
            ),
          ),

          const SizedBox(height: 30),
          _buildPrimaryButton('Continue', _nextPage),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildStep2Features() {
    return SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
      padding: EdgeInsets.only(
        left: VSPSpacing.md,
        right: VSPSpacing.md,
        top: VSPSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + VSPSpacing.md,
      ),
      child: Column(
        children: [
          _buildYesNoSection(AppLocalizations.of(context)!.bathrooms, _selectedBathOption == null ? null : _selectedBathOption == 'Yes', (val) => setState(() => _selectedBathOption = val ? 'Yes' : 'No')),
          const SizedBox(height: 20),
          _buildYesNoSection(AppLocalizations.of(context)!.cafeteria, _cafeteria, (val) => setState(() => _cafeteria = val)),
          const SizedBox(height: 20),
          _buildYesNoSection(AppLocalizations.of(context)!.garage, _garage, (val) => setState(() => _garage = val)),
          const SizedBox(height: 20),
          _buildYesNoSection(AppLocalizations.of(context)!.changingRoom, _changingRoom, (val) => setState(() => _changingRoom = val)),
          const SizedBox(height: 20),
          _buildTextField(
            AppLocalizations.of(context)!.seatCount, 
            '0', 
            controller: _seatsController,
            maxLength: 5,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          
          const SizedBox(height: 30),
          const Divider(color: VSPColors.divider),
          const SizedBox(height: 20),
          
          Align(
            alignment: Alignment.centerLeft,
            child: Text(AppLocalizations.of(context)!.amenities, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 16),
          _buildYesNoSection(AppLocalizations.of(context)!.ballAvailableLabel, _hasBall, (val) => setState(() => _hasBall = val)),
          
          if (_hasBall == true) ...[
            const SizedBox(height: 16),
             _buildTextField(
               'Ball Rental Price (EGP)', 
               '20.0', 
              controller: _ballPriceController,
               maxLength: 5,
               keyboardType: const TextInputType.numberWithOptions(decimal: true),
               inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
             ),
          ],
          const SizedBox(height: 20),
          const Divider(color: VSPColors.divider),
          const SizedBox(height: 20),
          // ── Deposit (العربون) ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.lock, color: VSPColors.accent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Require Booking Deposit (العربون)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: _requireDeposit,
                    onChanged: (val) {
                      setState(() {
                        _requireDeposit = val;
                        if (!val) {
                          _depositController.clear();
                        }
                      });
                    },
                    activeColor: VSPColors.accent,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Require upfront deposit that cannot exceed 50% of the hourly stadium price.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
              ),
              if (_requireDeposit) ...[
                const SizedBox(height: 12),
                _buildTextField(
                  'Deposit Amount (EGP)',
                  '0',
                  controller: _depositController,
                  maxLength: 7,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                ),
              ],
            ],
          ),
          const SizedBox(height: 40),
          _buildPrimaryButton('Continue', _nextPage),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildStep3Images() {
    return SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
      padding: EdgeInsets.only(
        left: VSPSpacing.md,
        right: VSPSpacing.md,
        top: VSPSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + VSPSpacing.md,
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.stadiumGallery,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: VSPSpacing.xs),
          Text(
            AppLocalizations.of(context)!.stadiumPhotosHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
          ),
          const SizedBox(height: 24),
          
          VspUploadMainCard(
            title: 'Add New Photo',
            isLoading: _isUploading,
            onTap: _pickImage,
          ),
          
          const SizedBox(height: 20),
          
          if (_images.isNotEmpty)
            Column(
              children: _images.asMap().entries.map((entry) {
                final index = entry.key;
                final img = entry.value;
                return _buildUploadCard(
                  title: 'Stadium Photo ${index + 1}',
                  fileUrl: img['url'],
                  isUploading: img['isUploading'] ?? false,
                  progress: img['progress'] ?? 0,
                  onTap: () {}, 
                  onDelete: () async {
                    if (img['url'] != null) {
                      await _storageService.deleteFile(img['url']!);
                    }
                    setState(() => _images.remove(img));
                  },
                  thumbnail: img['url'] != null 
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(img['url']!, width: 40, height: 40, fit: BoxFit.cover),
                      )
                    : (img['file'] != null 
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(img['file']!, width: 40, height: 40, fit: BoxFit.cover),
                          )
                        : null),
                );
              }).toList(),
            ),

          const SizedBox(height: 40),
          _buildPrimaryButton('Submit Stadium', _nextPage, isLoading: _isSaving),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }



  // --- Widgets ---

  Widget _buildTextField(
    String label, 
    String hint, {
    required TextEditingController controller, 
    bool readOnly = false, 
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VSPColors.textSecondary)),
        const SizedBox(height: VSPSpacing.xs),
        CustomTextField(
          controller: controller,
          hintText: hint,
          keyboardType: keyboardType ?? (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          onChanged: (val) {
            if (readOnly) {
              // If it's read only but somehow changed (not ideal for CustomTextField but keeping simple)
            }
          },
        ),
      ],
    );
  }

  Widget _buildSportDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.sportTypeLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: VSPColors.textSecondary,
              ),
        ),
        const SizedBox(height: VSPSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.md),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSportType,
              hint: Text(
                AppLocalizations.of(context)!.selectSport,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VSPColors.textSecondary,
                    ),
              ),
              dropdownColor: VSPColors.surface,
              isExpanded: true,
              items: VSPConstants.sports
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: Theme.of(context).textTheme.bodyMedium),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedSportType = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGovernorateDropdown() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final List<String> govs = EgyptGovernorates.allGovernorates;
    final currentVal = govs.contains(_governorate) ? _governorate : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.governorate, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VSPColors.textSecondary)),
        const SizedBox(height: VSPSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
          decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.md)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentVal,
              hint: Text(
                isArabic ? 'اختر محافظتك' : 'Select your governorate',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: VSPColors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
              dropdownColor: VSPColors.surface,
              isExpanded: true,
              items: govs.map((e) => DropdownMenuItem(value: e, child: Text(e, style: Theme.of(context).textTheme.bodyMedium))).toList(),
              onChanged: widget.stadiumId != null
                  ? null
                  : (val) => setState(() => _governorate = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeBox(String text, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? VSPColors.accentSoft : VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: isSelected ? VSPColors.accent : Colors.transparent),
      ),
      child: Center(child: Text(text, style: TextStyle(color: isSelected ? VSPColors.accent : VSPColors.textPrimary))),
    );
  }

  Widget _buildYesNoSection(String label, bool? value, ValueChanged<bool> onChanged) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Row(
          children: [
            _optionBtn(isArabic ? 'نعم' : 'Yes', value == true, () => onChanged(true)),
            const SizedBox(width: 10),
            _optionBtn(isArabic ? 'لا' : 'No', value != null && value == false, () => onChanged(false)),
          ],
        )
      ],
    );
  }

  Widget _optionBtn(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? VSPColors.accent : VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
        ),
        child: Text(text, style: TextStyle(color: selected ? Colors.black : VSPColors.textPrimary)),
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed, {bool isLoading = false}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: 1.0, // Always visible for now, but could be tied to form validity logic
      child: PrimaryButton(
        text: text,
        onPressed: isLoading ? () {} : onPressed,
        isLoading: isLoading,
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String? fileUrl,
    required bool isUploading,
    required int progress,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    Widget? thumbnail,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return InkWell(
      onTap: fileUrl == null ? onTap : null,
      child: VSPCard(
        padding: const EdgeInsets.all(VSPSpacing.md),
        margin: const EdgeInsets.only(bottom: VSPSpacing.md),
        child: Row(
          children: [
            if (thumbnail != null)
              thumbnail
            else
              Icon(
                fileUrl != null ? LucideIcons.checkCircle : LucideIcons.upload,
                color: fileUrl != null ? Colors.green : VSPColors.accent,
                size: 32,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (isUploading)
                    Text(isArabic ? "جاري الرفع... $progress%" : "Uploading... $progress%", style: const TextStyle(color: Colors.orange, fontSize: 12))
                  else if (fileUrl != null)
                    Text(isArabic ? "تم الرفع بنجاح" : "Uploaded successfully", style: const TextStyle(color: Colors.green, fontSize: 12))
                  else
                    Text(
                      isArabic ? "اضغط للرفع" : "Tap to upload (JPG, PNG <10MB)",
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(LucideIcons.trash2, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
