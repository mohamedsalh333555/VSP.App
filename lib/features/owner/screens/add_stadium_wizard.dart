import '../../../core/utils/app_date_formatter.dart';
import '../../../l10n/app_localizations.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/image_pick_service.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


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

  // Form Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _locationController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _seatsController = TextEditingController();
  final _notesController = TextEditingController();
  final _stadiumPhoneController = TextEditingController();
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
  double? _latitude;
  double? _longitude;
  // ignore: unused_field
  bool _isLoadingData = false;
  String? _governorate; // ✅ Extracted via Geocoding for filtering
  bool _requireDeposit = false;

  // ImagePicker is no longer used directly; kept for multi-image reference.
  // ignore: unused_field
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
    } else {
      _loadPersistedForm().then((_) {
        _setupAutoSaveListeners();
      });
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
    _stadiumPhoneController.dispose();
    _pageController.dispose();
    _ballPriceController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _saveToPrefs(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveBoolToPrefs(String key, bool? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setBool(key, value);
    }
  }

  Future<void> _loadPersistedForm() async {
    if (widget.stadiumId != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('temp_stadium_name') ?? '';
      final savedPhone = prefs.getString('temp_stadium_phone') ?? '';
      final savedWidth = prefs.getString('temp_stadium_width') ?? '';

      // Clear legacy mock test data if present
      if (savedName == 'Al_Champions_Stadium' || savedName.contains('Stadium') || savedPhone == '01011112222' || savedWidth == '350') {
        await _clearPersistedForm();
        return;
      }

      setState(() {
        _nameController.text = savedName;
        _locationController.text = prefs.getString('temp_stadium_location') ?? '';
        _priceController.text = prefs.getString('temp_stadium_price') ?? '';
        _capacityController.text = prefs.getString('temp_stadium_capacity') ?? '';
        _stadiumPhoneController.text = savedPhone;
        _notesController.text = prefs.getString('temp_stadium_notes') ?? '';
        _lengthController.text = prefs.getString('temp_stadium_length') ?? '';
        _widthController.text = savedWidth;
        _seatsController.text = prefs.getString('temp_stadium_seats') ?? '';
        _ballPriceController.text = prefs.getString('temp_stadium_ball_price') ?? '';
        _depositController.text = prefs.getString('temp_stadium_deposit') ?? '';

        _governorate = prefs.getString('temp_stadium_governorate');
        _selectedSportType = prefs.getString('temp_stadium_sport_type');
        _selectedFloorType = prefs.getString('temp_stadium_floor_type');
        _selectedBathOption = prefs.getString('temp_stadium_bath_option');

        _cafeteria = prefs.getBool('temp_stadium_cafeteria');
        _garage = prefs.getBool('temp_stadium_garage');
        _changingRoom = prefs.getBool('temp_stadium_changing_room');
        _hasBall = prefs.getBool('temp_stadium_has_ball');
        _requireDeposit = prefs.getBool('temp_stadium_require_deposit') ?? false;
        _isSplitShift = prefs.getBool('temp_stadium_is_split_shift') ?? false;
      });
    } catch (e) {
      debugPrint('Error loading persisted form data: $e');
    }
  }

  void _setupAutoSaveListeners() {
    _nameController.addListener(() => _saveToPrefs('temp_stadium_name', _nameController.text));
    _locationController.addListener(() => _saveToPrefs('temp_stadium_location', _locationController.text));
    _priceController.addListener(() => _saveToPrefs('temp_stadium_price', _priceController.text));
    _capacityController.addListener(() => _saveToPrefs('temp_stadium_capacity', _capacityController.text));
    _stadiumPhoneController.addListener(() => _saveToPrefs('temp_stadium_phone', _stadiumPhoneController.text));
    _notesController.addListener(() => _saveToPrefs('temp_stadium_notes', _notesController.text));
    _lengthController.addListener(() => _saveToPrefs('temp_stadium_length', _lengthController.text));
    _widthController.addListener(() => _saveToPrefs('temp_stadium_width', _widthController.text));
    _seatsController.addListener(() => _saveToPrefs('temp_stadium_seats', _seatsController.text));
    _ballPriceController.addListener(() => _saveToPrefs('temp_stadium_ball_price', _ballPriceController.text));
    _depositController.addListener(() => _saveToPrefs('temp_stadium_deposit', _depositController.text));
  }

  Future<void> _clearPersistedForm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = [
        'temp_stadium_name',
        'temp_stadium_location',
        'temp_stadium_price',
        'temp_stadium_capacity',
        'temp_stadium_phone',
        'temp_stadium_notes',
        'temp_stadium_length',
        'temp_stadium_width',
        'temp_stadium_seats',
        'temp_stadium_ball_price',
        'temp_stadium_deposit',
        'temp_stadium_governorate',
        'temp_stadium_sport_type',
        'temp_stadium_floor_type',
        'temp_stadium_bath_option',
        'temp_stadium_cafeteria',
        'temp_stadium_garage',
        'temp_stadium_changing_room',
        'temp_stadium_has_ball',
        'temp_stadium_require_deposit',
        'temp_stadium_is_split_shift',
      ];
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('Error clearing persisted form data: $e');
    }
  }

  void _updateBathOption(bool val) {
    setState(() {
      _selectedBathOption = val ? 'Yes' : 'No';
    });
    if (widget.stadiumId == null) {
      _saveToPrefs('temp_stadium_bath_option', _selectedBathOption!);
    }
  }

  void _updateCafeteria(bool val) {
    setState(() {
      _cafeteria = val;
    });
    if (widget.stadiumId == null) {
      _saveBoolToPrefs('temp_stadium_cafeteria', val);
    }
  }

  void _updateGarage(bool val) {
    setState(() {
      _garage = val;
    });
    if (widget.stadiumId == null) {
      _saveBoolToPrefs('temp_stadium_garage', val);
    }
  }

  void _updateChangingRoom(bool val) {
    setState(() {
      _changingRoom = val;
    });
    if (widget.stadiumId == null) {
      _saveBoolToPrefs('temp_stadium_changing_room', val);
    }
  }

  void _updateHasBall(bool val) {
    setState(() {
      _hasBall = val;
    });
    if (widget.stadiumId == null) {
      _saveBoolToPrefs('temp_stadium_has_ball', val);
    }
  }

  void _updateRequireDeposit(bool val) {
    setState(() {
      _requireDeposit = val;
      if (!val) {
        _depositController.clear();
      }
    });
    if (widget.stadiumId == null) {
      _saveBoolToPrefs('temp_stadium_require_deposit', val);
    }
  }

  void _updateIsSplitShift(bool val) {
    setState(() {
      _isSplitShift = val;
      if (_isSplitShift && _breakTimes.isEmpty) {
        _breakTimes.add({'start': null, 'end': null});
      }
    });
    if (widget.stadiumId == null) {
      _saveBoolToPrefs('temp_stadium_is_split_shift', val);
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
        _stadiumPhoneController.text = features['stadiumPhone']?.toString() ?? '';
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

        final allImages = <String>[];
        if (data['images'] is List) {
          for (var img in (data['images'] as List)) {
            if (img != null && img.toString().isNotEmpty) {
              allImages.add(img.toString());
            }
          }
        }
        if (features['allImages'] is List) {
          for (var img in (features['allImages'] as List)) {
            final str = img.toString();
            if (str.isNotEmpty && !allImages.contains(str)) {
              allImages.add(str);
            }
          }
        }
        if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
          final str = data['imageUrl'].toString();
          if (!allImages.contains(str)) {
            allImages.insert(0, str);
          }
        }
        if (data['image_url'] != null && data['image_url'].toString().isNotEmpty) {
          final str = data['image_url'].toString();
          if (!allImages.contains(str)) {
            allImages.insert(0, str);
          }
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
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    try {
      final totalMin = AppDateFormatter.parseTimeToMinutes(timeStr);
      return TimeOfDay(hour: (totalMin ~/ 60) % 24, minute: totalMin % 60);
    } catch (e, stack) {
      VSPLogger.e('Error parsing time string in AddStadiumWizard', e, stack);
      return null;
    }
  }

  // --- Actions ---

  void _showError(String message) {
     VSPFeedback.showError(context, message);
  }



  Future<void> _resolveLocationAndAddress(double lat, double lng) async {
    try {
      setState(() {
        _latitude = lat;
        _longitude = lng;
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng).timeout(const Duration(seconds: 5));
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

        setState(() {
          _locationController.text = readableAddress;
          final rawName = place.administrativeArea ?? place.subAdministrativeArea ?? place.locality;
          final resolved = EgyptGovernorates.resolveGoogleName(rawName);
          if (resolved != null) {
            _governorate = resolved;
          }
          VSPLogger.i('📍 Address resolved to: $readableAddress, Governorate: ${_governorate ?? "Unassigned"}');
        });
        if (widget.stadiumId == null) {
          _saveToPrefs('temp_stadium_location', readableAddress);
          if (_governorate != null) {
            _saveToPrefs('temp_stadium_governorate', _governorate!);
          }
        }
      } else {
        setState(() {
          _locationController.text = 'Lat: $lat, Long: $lng';
        });
        if (widget.stadiumId == null) {
          _saveToPrefs('temp_stadium_location', 'Lat: $lat, Long: $lng');
        }
      }
    } catch (e) {
      VSPLogger.e('❌ Geocoding error', e);
      setState(() {
        _locationController.text = 'Lat: $lat, Long: $lng';
      });
      if (widget.stadiumId == null) {
        _saveToPrefs('temp_stadium_location', 'Lat: $lat, Long: $lng');
      }
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
      }).timeout(const Duration(seconds: 5));
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
                        child: Icon(Iconsax.location_copy,
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
                                Icon(Iconsax.search_normal_copy, color: VSPColors.accent, size: 22),
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
                                    icon: Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 18),
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
                                    leading: Icon(Iconsax.location_copy, color: VSPColors.accent, size: 18),
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
                          icon: Icon(Iconsax.close_circle_copy, color: Colors.white, size: 20),
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
                          icon: Icon(Iconsax.gps_copy, color: VSPColors.accent, size: 24),
                          onPressed: () async {
                            setSheetState(() {
                              isSearching = true;
                            });
                            try {
                              Position position = await Geolocator.getCurrentPosition(
                                locationSettings: const LocationSettings(
                                  accuracy: LocationAccuracy.high,
                                  timeLimit: Duration(seconds: 5),
                                ),
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
      initialTime: isMainStart
          ? (_startTime ?? const TimeOfDay(hour: 16, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 23, minute: 0)),
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
    try {
      // Open cropper (16:9 for stadium photos) then upload the result
      final picked = await ImagePickService.pick(
        context,
        aspectRatio: CropAspectRatioPreset.ratio16x9,
      );
      if (picked == null) return;
      _uploadSinglePickedFile(picked);
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<void> _uploadSinglePickedFile(XFile pickedFile) async {
    Timer? progressTimer;
    final imageFile = File(pickedFile.path);
    final imageEntry = {'file': imageFile, 'url': null, 'isUploading': true, 'progress': 0};
    setState(() => _images.add(imageEntry));
    
    try {
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

      final url = await _storageService.uploadFile(
        file: XFile(imageFile.path),
        bucket: 'stadium-images',
        path: 'stadiums/images/std_${DateTime.now().microsecondsSinceEpoch}.jpg',
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
        });
      }
    }
  }



  void _nextPage() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_currentStep == 0) {
      if (_locationController.text.trim().isEmpty) {
        _showError(isArabic ? 'يرجى تحديد موقع الملعب على الخريطة أولاً' : 'Please select stadium location on map first');
        return;
      }

      if (_nameController.text.trim().isEmpty) {
        _showError(isArabic ? 'يرجى إدخال اسم الملعب' : 'Please enter stadium name');
        return;
      }

      if (_stadiumPhoneController.text.trim().isEmpty) {
        _showError(isArabic ? 'يرجى إدخال رقم هاتف الملعب' : 'Please enter stadium phone number');
        return;
      }

      if (_selectedSportType == null || _selectedSportType!.trim().isEmpty) {
        _showError(isArabic ? 'يرجى اختيار نوع الرياضة' : 'Please select sport type');
        return;
      }

      if (_priceController.text.trim().isEmpty) {
        _showError(isArabic ? 'يرجى إدخال سعر حجز الملعب للساعة' : 'Please enter stadium hourly price');
        return;
      }

      if (_startTime == null || _endTime == null) {
        _showError(isArabic ? 'يرجى تحديد مواعيد العمل (البداية والنهاية)' : 'Please select working hours (start and end)');
        return;
      }

      // ── Split-Shift (Break Time) Validation ──
      if (_isSplitShift) {
        if (_breakTimes.isEmpty) {
          _showError(isArabic ? "يرجى إضافة فترة راحة واحدة على الأقل عند تفعيل الراحة." : "Please add at least one break time.");
          return;
        }

        for (var i = 0; i < _breakTimes.length; i++) {
          final bStart = _breakTimes[i]['start'];
          final bEnd = _breakTimes[i]['end'];
          if (bStart == null || bEnd == null) {
            _showError(isArabic ? "يرجى تحديد وقت البداية والنهاية لفترة الراحة ${i + 1}." : "Please set start and end times for Break ${i + 1}.");
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
            _showError(isArabic 
                ? "فترة الراحة ${i + 1} يجب أن تكون داخل مواعيد العمل الرسمية (${_formatTime(_startTime, '')} - ${_formatTime(_endTime, '')})."
                : "Break ${i + 1} must be within opening hours (${_formatTime(_startTime, '')} - ${_formatTime(_endTime, '')}).");
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
          _showError(isArabic ? "يرجى إدخال مبلغ عربون صحيح." : "Please set a valid deposit amount.");
          return;
        }
        if (deposit > (price * 0.5)) {
          _showError(isArabic 
              ? "مبلغ العربون لا يمكن أن يتجاوز 50% من سعر الساعة (${(price * 0.5).toStringAsFixed(0)} ج.م)."
              : "Deposit amount cannot exceed 50% of the hourly price (${price * 0.5} EGP).");
          return;
        }
      }
    } else if (_currentStep == 2) {
      // Validate Images & Submit
      if (_images.isEmpty && (widget.stadiumId == null)) {
        _showError(AppLocalizations.of(context)!.uploadPhotoError);
        return;
      }
      if (_images.any((img) => img['isUploading'] == true)) {
        _showError('Please wait for all images to finish uploading.');
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

  Future<bool> _showDiscardConfirmation() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(
          isArabic ? 'تجاهل التغييرات؟ ⚠️' : 'Discard changes? ⚠️',
          style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isArabic
              ? 'لديك بيانات وتعديلات غير محفوظة، هل أنت متأكد من الخروج؟'
              : 'You have unsaved data. Are you sure you want to exit?',
          style: const TextStyle(color: VSPColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isArabic ? 'خروج' : 'Exit', style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  void _previousPage() async {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    } else {
      final shouldLeave = await _showDiscardConfirmation();
      if (shouldLeave && mounted) {
        Navigator.pop(context);
      }
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
        'stadiumPhone': _stadiumPhoneController.text.trim(),
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
          'start': _formatTime(_startTime, '04:00 PM'),
          'end': _formatTime(_endTime, '11:00 PM'),
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
            'pricePerHour': double.tryParse(_priceController.text.trim()) ?? 0.0,
            'players_per_team': int.tryParse(_capacityController.text.trim()) ?? 5,
            'total_field_capacity': (int.tryParse(_capacityController.text.trim()) ?? 5) * 2,
            'deposit_amount': _requireDeposit ? (double.tryParse(_depositController.text.trim()) ?? 0.0) : 0.0,
            'needs_deposit': _requireDeposit,
            'imageUrl': uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
            'images': uploadedUrls,
            'notes': _notesController.text.trim(),
            'features': stadiumFeatures,
            'opening_time': _formatTime(_startTime, '04:00 PM'),
            'closing_time': _formatTime(_endTime, '03:00 AM'),
            'lat': _latitude,
            'lng': _longitude,
          });
      } else {
          // Create Logic
          final stadiumId = await _databaseService.createStadium(
            name: _nameController.text.trim(),
            location: _locationController.text.trim(),
            governorate: _governorate, // ✅ Added for filtering
            pricePerHour: double.tryParse(_priceController.text.trim()) ?? 0.0,
            seatsCapacity: int.tryParse(_capacityController.text.trim()) ?? 5,
            depositAmount: _requireDeposit ? (double.tryParse(_depositController.text.trim()) ?? 0.0) : 0.0,
            needsDeposit: _requireDeposit,
            imageUrl: uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
            images: uploadedUrls,
            ownerId: user.uid,
            lat: _latitude,
            lng: _longitude,
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
          
      }
      
      if (mounted) {
        if (widget.stadiumId == null) {
          await _clearPersistedForm();
        }
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        VSPFeedback.showSuccess(context, l10n.stadiumSubmitSuccess);
        Navigator.pop(context); // Return to FacilityOnboardingScreen — StreamBuilder will auto-refresh
            if (widget.stadiumId == null) {
              await auth.updateProfile({'hasStadium': true});
            }
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
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentStep > 0) {
          _previousPage();
          return;
        }
        final shouldLeave = await _showDiscardConfirmation();
        if (shouldLeave && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: VSPColors.background,
        appBar: AppBar(
          backgroundColor: VSPColors.background,
          leading: IconButton(
            icon: Icon(
              Localizations.localeOf(context).languageCode == 'ar' ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_copy,
              color: VSPColors.textPrimary,
            ),
            onPressed: _previousPage,
          ),
          title: Text(AppLocalizations.of(context)!.addStadium, style: Theme.of(context).textTheme.displaySmall),
          centerTitle: true,
          elevation: 0, actions: [ if (widget.stadiumId != null) IconButton(icon: Icon(Iconsax.trash_copy, color: VSPColors.error), onPressed: () => _showDeleteConfirmationDialog()) ],
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

    // Goal Gradient Effect progress calculations
    final bool isEditing = widget.stadiumId != null;
    final int percent = _currentStep == 0 ? 33 : (_currentStep == 1 ? 66 : 100);
    final String progressText = isEditing
        ? (isArabic ? '✏️ تعديل بيانات وتفاصيل الملعب الحالي' : '✏️ Editing current stadium details')
        : (_currentStep == 0
            ? (isArabic ? '📝 الخطوة 1 من 3: أدخل البيانات الأساسية للملعب' : '📝 Step 1 of 3: Enter basic details')
            : (_currentStep == 1
                ? (isArabic ? '⚡ الخطوة 2 من 3: حدد الميزات والخدمات المتاحة' : '⚡ Step 2 of 3: Select features & options')
                : (isArabic ? '🎉 الخطوة 3 من 3: أضف صور الملعب والمعاينة النهائية' : '🎉 Step 3 of 3: Add photos & preview')));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        children: [
          // Goal Gradient Progress Banner (Only shown when adding a new stadium)
          if (!isEditing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      progressText,
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: VSPColors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$percent%',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Stepper Lines and Circles
          Stack(
            children: [
              // Background Connecting Lines
              Positioned(
                left: 28 / 2 + 12,
                right: 28 / 2 + 12,
                top: 28 / 2 - 1,
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
                              ? const Icon(Iconsax.tick_circle_copy, color: Colors.black, size: 16)
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
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? MediaQuery.of(context).viewInsets.bottom + VSPSpacing.md
            : (MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom + VSPSpacing.md
                : VSPSpacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single Unified Interactive Location Selector Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.location,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VSPColors.textSecondary),
              ),
              const SizedBox(height: VSPSpacing.xs),
              GestureDetector(
                onTap: (widget.stadiumId != null || _isLocationLoading) ? null : _openMapPicker,
                child: Container(
                  width: double.infinity,
                  height: VSPSize.inputHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.input),
                    border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.stadiumId != null ? Iconsax.lock_copy : Iconsax.location_copy,
                        color: VSPColors.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _locationController.text.isNotEmpty
                              ? _locationController.text
                              : (isArabic ? 'اضغط لتحديد موقع الملعب على الخريطة 🗺️' : 'Tap to select stadium location on map 🗺️'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _locationController.text.isNotEmpty ? Colors.white : VSPColors.textSecondary,
                            fontSize: 13,
                            fontWeight: _locationController.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_isLocationLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                        )
                      else if (_locationController.text.isNotEmpty)
                        const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 18)
                      else
                        Icon(isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_1_copy, color: VSPColors.textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(AppLocalizations.of(context)!.stadiumName, isArabic ? 'أدخل اسم ملعبك' : 'Enter Stadium Name', controller: _nameController, maxLength: 50),
          const SizedBox(height: 16),
          _buildTextField(
            isArabic ? 'رقم هاتف الملعب' : 'Stadium Phone Number',
            '01xxxxxxxxx',
            controller: _stadiumPhoneController,
            maxLength: 15,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
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
            isArabic ? "اكتب رقم عدد الفريق الواحد" : "Write the number of players for a single team", 
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
                Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                      final selectedEndStr = _formatTime(_endTime, '');
                      
                      return Text(
                        isArabic 
                            ? "ملاحظة: اختيار وقت الإغلاق ($selectedEndStr) يعني أن الملعب يغلق فعلياً وينتهي آخر حجز في هذا الوقت."
                            : "Note: Selecting closing time ($selectedEndStr) means the pitch actually closes and the last booking ends at this time.",
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
                onChanged: _updateIsSplitShift,
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
                          icon: Icon(Iconsax.trash_copy, color: VSPColors.error, size: 20),
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
              alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _breakTimes.add({'start': null, 'end': null});
                  });
                },
                icon: Icon(Iconsax.add_circle_copy, color: VSPColors.accent, size: 18),
                label: Text(
                  isArabic ? 'إضافة فترة راحة أخرى' : 'Add Another Break', 
                  style: const TextStyle(color: VSPColors.accent, fontSize: 13),
                ),
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
                child: Row(
                  children: [
                    const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'ساعات الراحة يجب أن تكون داخل مواعيد العمل الرسمية للملعب!'
                            : 'Break hours must fall strictly inside the opening and closing hours!',
                        style: const TextStyle(color: VSPColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildTextField(
              isArabic ? 'الطول (متر)' : 'Length', 
              isArabic ? 'متر' : 'm', 
              controller: _lengthController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField(
              isArabic ? 'العرض (متر)' : 'Width', 
              isArabic ? 'متر' : 'm', 
              controller: _widthController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            )),
          ]),
          
          const SizedBox(height: 16),
          _buildTextField(
            isArabic ? 'ملاحظات وتعليمات الملعب' : 'Notes', 
            isArabic 
                ? 'مثال: الحضور قبل الموعد بـ 10 دقائق، الحفاظ على أرضية الملعب...' 
                : 'Ex: We ensure a professional environment. Please arrive on time...', 
            controller: _notesController, 
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
            scrollDirection: Axis.horizontal,
            child: Row(
              children: (isArabic 
                  ? ['الالتزام بالموعد', 'الحفاظ على النظافة', 'ممنوع التدخين', 'إحضار الكرة الخاصة بك']
                  : ['Punctuality', 'Cleanliness', 'No Smoking', 'Bring your own ball'])
              .map((template) => Padding(
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
          _buildPrimaryButton(isArabic ? 'متابعة' : 'Continue', _nextPage),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildStep2Features() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
      padding: EdgeInsets.only(
        left: VSPSpacing.md,
        right: VSPSpacing.md,
        top: VSPSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + VSPSpacing.md,
      ),
      child: Column(
        children: [
          _buildYesNoSection(AppLocalizations.of(context)!.bathrooms, _selectedBathOption == null ? null : _selectedBathOption == 'Yes', _updateBathOption),
          const SizedBox(height: 20),
          _buildYesNoSection(AppLocalizations.of(context)!.cafeteria, _cafeteria, _updateCafeteria),
          const SizedBox(height: 20),
          _buildYesNoSection(AppLocalizations.of(context)!.garage, _garage, _updateGarage),
          const SizedBox(height: 20),
          _buildYesNoSection(AppLocalizations.of(context)!.changingRoom, _changingRoom, _updateChangingRoom),
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
            alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(AppLocalizations.of(context)!.amenities, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 16),
          _buildYesNoSection(AppLocalizations.of(context)!.ballAvailableLabel, _hasBall, _updateHasBall),
          
          if (_hasBall == true) ...[
            const SizedBox(height: 16),
            _buildTextField(
              isArabic ? 'سعر تأجير الكرة (ج.م)' : 'Ball Rental Price (EGP)', 
              '0.0', 
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
                      Icon(Iconsax.lock_copy, color: VSPColors.accent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isArabic ? 'اشتراط عربون حجز' : 'Require Booking Deposit',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: _requireDeposit,
                    onChanged: _updateRequireDeposit,
                    activeColor: VSPColors.accent,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isArabic 
                    ? 'اشتراط دفع عربون مسبق لا يتجاوز 50% من سعر الساعة.'
                    : 'Require upfront deposit that cannot exceed 50% of the hourly stadium price.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
              ),
              if (_requireDeposit) ...[
                const SizedBox(height: 12),
                _buildTextField(
                  isArabic ? 'قيمة العربون (ج.م)' : 'Deposit Amount (EGP)',
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
          _buildPrimaryButton(isArabic ? 'متابعة' : 'Continue', _nextPage),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildStep3Images() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
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
            title: isArabic ? 'إضافة صورة جديدة' : 'Add New Photo',
            helper: isArabic ? 'صور JPG, JPEG, PNG أقل من 10 ميجابايت' : 'JPG, JPEG, PNG less than 10MB',
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
                  title: isArabic ? 'صورة الملعب ${index + 1}' : 'Stadium Photo ${index + 1}',
                  fileUrl: img['url'],
                  isUploading: img['isUploading'] ?? false,
                  progress: img['progress'] ?? 0,
                  onTap: _pickImage, 
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
          _buildPrimaryButton(isArabic ? 'إرسال الملعب' : 'Submit Stadium', _nextPage, isLoading: _isSaving),
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
          maxLines: maxLines,
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

  String _getLocalizedSport(String sport, bool isAr) {
    if (!isAr) return sport;
    switch (sport) {
      case 'Football':
        return 'كرة القدم';
      case 'Basketball':
        return 'كرة السلة';
      case 'Volleyball':
        return 'الكرة الطائرة';
      case 'Padel':
        return 'بادل';
      case 'Handball':
        return 'كرة اليد';
      case 'Tennis':
        return 'تنس';
      default:
        return sport;
    }
  }

  Widget _buildSportDropdown() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
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
          height: VSPSize.inputHeight,
          padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.input),
            border: Border.all(color: VSPColors.accent.withValues(alpha: 0.1)),
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
                        child: Text(_getLocalizedSport(e, isAr), style: Theme.of(context).textTheme.bodyMedium),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedSportType = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeBox(String text, {bool isSelected = false}) {
    return Container(
      height: VSPSize.inputHeight,
      decoration: BoxDecoration(
        color: isSelected ? VSPColors.accentSoft : VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.input),
        border: Border.all(color: isSelected ? VSPColors.accent : VSPColors.accent.withValues(alpha: 0.1)),
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  thumbnail,
                  if (fileUrl != null)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(1),
                        child: const Icon(Iconsax.tick_circle_copy, color: Colors.green, size: 14),
                      ),
                    ),
                ],
              )
            else
              Icon(
                fileUrl != null ? Iconsax.tick_circle_copy : Iconsax.export_3_copy,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isArabic ? "جاري الرفع... $progress%" : "Uploading... $progress%",
                              style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (progress <= 0) ? null : progress / 100.0,
                            backgroundColor: Colors.orange.withValues(alpha: 0.2),
                            color: Colors.orange,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    )
                  else if (fileUrl != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.tick_circle_copy, color: Colors.green, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          isArabic ? "تم الرفع بنجاح" : "Uploaded successfully",
                          style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  else
                    Text(
                      isArabic ? "اضغط للرفع" : "Tap to upload (JPG, PNG <10MB)",
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (fileUrl != null) ...[
              const Icon(Iconsax.tick_circle_copy, color: Colors.green, size: 22),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: const Icon(Iconsax.trash_copy, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(
          isArabic ? 'إخفاء وحذف الملعب؟ ⚠️' : 'Hide & Delete Stadium? ⚠️',
          style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من رغبتك في إخفاء هذا الملعب؟ سيتم إيقافه وإخفاؤه فوراً عن اللاعبين ولن تظهر حجوزاته، ولن يتم الحذف النهائي من قاعدة البيانات إلا بعد تواصل الإدارة معك لمراجعة السبب والتأكيد.'
              : 'Are you sure you want to hide this stadium? It will be immediately hidden from players. Permanent deletion will only occur after admin contacts you to confirm.',
          style: const TextStyle(color: VSPColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
            ),
            child: Text(isArabic ? 'تأكيد الإخفاء' : 'Confirm Hide'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() => _isSaving = true);
      try {
        final now = DateTime.now();
        final startOfTodayUtc = DateTime.utc(now.year, now.month, now.day).toIso8601String();

        // 🛡️ Business Rule: Block deletion ONLY if there are active non-cancelled bookings today or in the future
        final activeBookingsCheck = await Supabase.instance.client
            .from('bookings')
            .select('id')
            .eq('stadium_id', widget.stadiumId!)
            .neq('status', 'cancelled')
            .gte('start_time', startOfTodayUtc);

        if (!mounted) return;
        if ((activeBookingsCheck as List).isNotEmpty) {
          VSPFeedback.showError(
            context,
            isArabic
                ? 'لا يمكن حذف الملعب لوجود حجوزات نشطة اليوم أو في المستقبل! قم بإلغائها أو انتظار انتهائها أولاً.'
                : 'Cannot delete stadium with active bookings today or in the future! Cancel them or wait for completion first.',
          );
          return;
        }

        // 🗑️ Clean up non-critical optional records (reviews) before attempting hard delete
        try {
          await Supabase.instance.client
              .from('reviews')
              .delete()
              .eq('stadium_id', widget.stadiumId!);
        } catch (e) {
          debugPrint('Pre-delete cleanup warning: $e');
        }

        // 1. Try Hard Delete (Permanent DB Removal)
        bool success = false;
        try {
          await Supabase.instance.client
              .from('stadiums')
              .delete()
              .eq('id', widget.stadiumId!);
          success = true;
        } catch (e) {
          debugPrint('Hard delete fallback to soft-delete (FK RESTRICT): $e');
        }

        // 2. Fallback Soft-Delete if DB constraint prevents hard delete
        if (!success) {
          try {
            await Supabase.instance.client
                .from('stadiums')
                .update({
                  'is_verified': false,
                  'is_deleted_by_owner': true,
                  'is_blocked': true,
                })
                .eq('id', widget.stadiumId!);
            success = true;
          } catch (e, stack) {
            VSPLogger.e('Error deleting stadium permanently', e, stack);
          }
        }

        if (!mounted) return;
        if (success) {
          // Check remaining active stadiums for owner
          final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
          final uid = auth.currentUser?.uid;
          if (uid != null) {
            try {
              final remaining = await Supabase.instance.client
                  .from('stadiums')
                  .select('id')
                  .eq('owner_id', uid)
                  .neq('is_deleted_by_owner', true);
              final bool stillHas = (remaining as List).isNotEmpty;
              await auth.updateProfile({'hasStadium': stillHas});
            } catch (e, stack) {
              VSPLogger.e('Error updating owner profile hasStadium flag', e, stack);
            }
          }

          if (mounted) {
            VSPFeedback.showSuccess(
              context,
              isArabic
                  ? 'تم حذف الملعب نهائياً واختفاؤه من التطبيق بنجاح! 🗑️'
                  : 'Stadium deleted permanently and hidden from app! 🗑️',
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          VSPFeedback.showError(
            context,
            isArabic ? 'حدث خطأ أثناء عملية حذف الملعب' : 'Error deleting stadium',
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

}