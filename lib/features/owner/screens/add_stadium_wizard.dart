import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/services/image_pick_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/vsp_back_button.dart';

import '../widgets/add_stadium/add_stadium_location_picker_sheet.dart';
import '../widgets/add_stadium/add_stadium_step_indicator.dart';
import '../widgets/add_stadium/add_stadium_step1_details.dart';
import '../widgets/add_stadium/add_stadium_step2_features.dart';
import '../widgets/add_stadium/add_stadium_step3_images.dart';

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
 String? _governorate; // Extracted via Geocoding for filtering
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

 String _getDraftPrefix() {
 try {
 final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
 final uid = auth.userModel?.uid ?? auth.currentUser?.uid ?? auth.firebaseUser?.id ?? '';
 return uid.isNotEmpty ? 'vsp_draft_stadium_${uid}_' : 'temp_stadium_';
 } catch (_) {
 return 'temp_stadium_';
 }
 }

 Future<void> _saveToPrefs(String key, String value) async {
 final prefs = await SharedPreferences.getInstance();
 final prefix = _getDraftPrefix();
 await prefs.setString('$prefix$key', value);
 }

 Future<void> _saveBoolToPrefs(String key, bool? value) async {
 final prefs = await SharedPreferences.getInstance();
 final prefix = _getDraftPrefix();
 if (value == null) {
 await prefs.remove('$prefix$key');
 } else {
 await prefs.setBool('$prefix$key', value);
 }
 }

 Future<void> _saveDoubleToPrefs(String key, double? value) async {
 final prefs = await SharedPreferences.getInstance();
 final prefix = _getDraftPrefix();
 if (value == null) {
 await prefs.remove('$prefix$key');
 } else {
 await prefs.setDouble('$prefix$key', value);
 }
 }

 Future<void> _saveStepToPrefs(int step) async {
 if (widget.stadiumId != null) return;
 final prefs = await SharedPreferences.getInstance();
 final prefix = _getDraftPrefix();
 await prefs.setInt('${prefix}current_step', step);
 }

 Future<void> _saveWorkingHoursToPrefs() async {
 if (widget.stadiumId != null) return;
 if (_startTime != null) {
 await _saveToPrefs('start_time', '${_startTime!.hour}:${_startTime!.minute}');
 }
 if (_endTime != null) {
 await _saveToPrefs('end_time', '${_endTime!.hour}:${_endTime!.minute}');
 }
 if (_breakTimes.isNotEmpty) {
 final list = _breakTimes.map((bt) => {
 'start': bt['start'] != null ? '${bt['start']!.hour}:${bt['start']!.minute}' : null,
 'end': bt['end'] != null ? '${bt['end']!.hour}:${bt['end']!.minute}' : null,
 }).toList();
 await _saveToPrefs('break_times', json.encode(list));
 }
 }

 Future<void> _saveImagesToPrefs() async {
 if (widget.stadiumId != null) return;
 final savedList = _images
 .where((img) => img['url'] != null && img['url'].toString().isNotEmpty)
 .map((img) => {'url': img['url'], 'progress': 100, 'isUploading': false})
 .toList();
 await _saveToPrefs('images', json.encode(savedList));
 }

 Future<void> _loadPersistedForm() async {
 if (widget.stadiumId != null) return;
 try {
 final prefs = await SharedPreferences.getInstance();
 final prefix = _getDraftPrefix();

 String getStr(String key) => prefs.getString('$prefix$key') ?? prefs.getString('temp_stadium_$key') ?? '';
 bool? getBool(String key) => prefs.getBool('$prefix$key') ?? prefs.getBool('temp_stadium_$key');
 double? getDouble(String key) => prefs.getDouble('$prefix$key') ?? prefs.getDouble('temp_stadium_$key');
 int? getInt(String key) => prefs.getInt('${prefix}current_step') ?? prefs.getInt('temp_stadium_current_step');

 final savedName = getStr('name');
 final savedPhone = getStr('phone');
 final savedWidth = getStr('width');
 final savedStep = getInt('current_step') ?? 0;

 setState(() {
 _nameController.text = savedName;
 _locationController.text = getStr('location');
 _priceController.text = getStr('price');
 _capacityController.text = getStr('capacity');
 _stadiumPhoneController.text = savedPhone;
 _notesController.text = getStr('notes');
 _lengthController.text = getStr('length');
 _widthController.text = savedWidth;
 _seatsController.text = getStr('seats');
 _ballPriceController.text = getStr('ball_price');
 _depositController.text = getStr('deposit');

 final savedGov = getStr('governorate');
 _governorate = savedGov.isNotEmpty ? savedGov : null;

 final savedSport = getStr('sport_type');
 _selectedSportType = savedSport.isNotEmpty ? savedSport : null;

 final savedFloor = getStr('floor_type');
 _selectedFloorType = savedFloor.isNotEmpty ? savedFloor : null;

 final savedBath = getStr('bath_option');
 _selectedBathOption = savedBath.isNotEmpty ? savedBath : null;

 _cafeteria = getBool('cafeteria');
 _garage = getBool('garage');
 _changingRoom = getBool('changing_room');
 _hasBall = getBool('has_ball');
 _requireDeposit = getBool('require_deposit') ?? false;
 _isSplitShift = getBool('is_split_shift') ?? false;

 _latitude = getDouble('lat');
 _longitude = getDouble('lng');

 final startTimeStr = getStr('start_time');
 if (startTimeStr.isNotEmpty) {
 final parts = startTimeStr.split(':');
 if (parts.length >= 2) {
 _startTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 16, minute: int.tryParse(parts[1]) ?? 0);
 }
 }

 final endTimeStr = getStr('end_time');
 if (endTimeStr.isNotEmpty) {
 final parts = endTimeStr.split(':');
 if (parts.length >= 2) {
 _endTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 23, minute: int.tryParse(parts[1]) ?? 0);
 }
 }

 final breakTimesStr = getStr('break_times');
 if (breakTimesStr.isNotEmpty) {
 try {
 final List decoded = json.decode(breakTimesStr);
 _breakTimes = decoded.map((item) {
 TimeOfDay? start;
 TimeOfDay? end;
 if (item['start'] != null) {
 final sp = item['start'].toString().split(':');
 if (sp.length >= 2) start = TimeOfDay(hour: int.tryParse(sp[0]) ?? 0, minute: int.tryParse(sp[1]) ?? 0);
 }
 if (item['end'] != null) {
 final ep = item['end'].toString().split(':');
 if (ep.length >= 2) end = TimeOfDay(hour: int.tryParse(ep[0]) ?? 0, minute: int.tryParse(ep[1]) ?? 0);
 }
 return {'start': start, 'end': end};
 }).toList();
 } catch (_) {}
 }

 final imagesStr = getStr('images');
 if (imagesStr.isNotEmpty) {
 try {
 final List decoded = json.decode(imagesStr);
 _images.clear();
 for (var item in decoded) {
 if (item is Map) {
 _images.add(Map<String, dynamic>.from(item));
 } else if (item is String && item.isNotEmpty) {
 _images.add({'url': item, 'progress': 100, 'isUploading': false});
 }
 }
 } catch (_) {}
 }

 if (savedStep > 0 && savedStep <= 2) {
 _currentStep = savedStep;
 WidgetsBinding.instance.addPostFrameCallback((_) {
 if (_pageController.hasClients) {
 _pageController.jumpToPage(savedStep);
 }
 });
 }
 });
 } catch (e) {
 debugPrint('Error loading persisted form data: $e');
 }
 }

 void _setupAutoSaveListeners() {
 _nameController.addListener(() => _saveToPrefs('name', _nameController.text));
 _locationController.addListener(() => _saveToPrefs('location', _locationController.text));
 _priceController.addListener(() => _saveToPrefs('price', _priceController.text));
 _capacityController.addListener(() => _saveToPrefs('capacity', _capacityController.text));
 _stadiumPhoneController.addListener(() => _saveToPrefs('phone', _stadiumPhoneController.text));
 _notesController.addListener(() => _saveToPrefs('notes', _notesController.text));
 _lengthController.addListener(() => _saveToPrefs('length', _lengthController.text));
 _widthController.addListener(() => _saveToPrefs('width', _widthController.text));
 _seatsController.addListener(() => _saveToPrefs('seats', _seatsController.text));
 _ballPriceController.addListener(() => _saveToPrefs('ball_price', _ballPriceController.text));
 _depositController.addListener(() => _saveToPrefs('deposit', _depositController.text));
 }

 Future<void> _clearPersistedForm() async {
 try {
 final prefs = await SharedPreferences.getInstance();
 final prefix = _getDraftPrefix();
 final suffixes = [
 'current_step',
 'name',
 'location',
 'lat',
 'lng',
 'governorate',
 'price',
 'capacity',
 'phone',
 'notes',
 'length',
 'width',
 'seats',
 'ball_price',
 'deposit',
 'sport_type',
 'floor_type',
 'bath_option',
 'cafeteria',
 'garage',
 'changing_room',
 'has_ball',
 'require_deposit',
 'is_split_shift',
 'start_time',
 'end_time',
 'break_times',
 'images',
 ];
 for (final s in suffixes) {
 await prefs.remove('$prefix$s');
 await prefs.remove('temp_stadium_$s');
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
 _saveToPrefs('bath_option', _selectedBathOption!);
 }
 }

 void _updateCafeteria(bool val) {
 setState(() {
 _cafeteria = val;
 });
 if (widget.stadiumId == null) {
 _saveBoolToPrefs('cafeteria', val);
 }
 }

 void _updateGarage(bool val) {
 setState(() {
 _garage = val;
 });
 if (widget.stadiumId == null) {
 _saveBoolToPrefs('garage', val);
 }
 }

 void _updateChangingRoom(bool val) {
 setState(() {
 _changingRoom = val;
 });
 if (widget.stadiumId == null) {
 _saveBoolToPrefs('changing_room', val);
 }
 }

 void _updateHasBall(bool val) {
 setState(() {
 _hasBall = val;
 });
 if (widget.stadiumId == null) {
 _saveBoolToPrefs('has_ball', val);
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
 _saveBoolToPrefs('require_deposit', val);
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
 _saveBoolToPrefs('is_split_shift', val);
 }
 }

 Future<void> _loadStadiumData() async {
 setState(() => _isLoadingData = true);
 try {
 final data = await _databaseService.getStadiumSnapshot(widget.stadiumId!);
 if (data != null) {
 _nameController.text = data['name'] ?? '';
 _locationController.text = data['location'] ?? '';
 // إصلاح قراءة السعر من حقل قاعدة البيانات الفعلي price_per_hour
 _priceController.text = (data['price_per_hour'] ?? data['pricePerHour'] ?? 0).toString();
 _capacityController.text = (data['players_per_team'] ?? data['playersPerTeam'] ?? 5).toString();
 final depositVal = data['deposit_amount'] ?? data['depositAmount'] ?? 0.0;
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




  Future<void> _openMapPicker() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    setState(() => _isLocationLoading = true);
    try {
      final result = await AddStadiumLocationPickerSheet.show(
        context,
        initialLat: _latitude,
        initialLng: _longitude,
      );
      if (result != null && mounted) {
        setState(() {
          _latitude = result.latitude;
          _longitude = result.longitude;
          _locationController.text = result.address;
          if (result.governorate != null) {
            _governorate = result.governorate;
          }
        });
        if (widget.stadiumId == null) {
          _saveDoubleToPrefs('lat', result.latitude);
          _saveDoubleToPrefs('lng', result.longitude);
          _saveToPrefs('location', result.address);
          if (result.governorate != null) {
            _saveToPrefs('governorate', result.governorate!);
          }
        }
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم تحديد موقع الملعب بنجاح! 📍' : 'Stadium location selected successfully! 📍',
        );
      }
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

 Future<void> _selectTime(BuildContext context, bool isMainStart) async {
 final TimeOfDay? picked = await showTimePicker(
 context: context,
 initialTime: isMainStart
 ? (_startTime ?? const TimeOfDay(hour: 16, minute: 0))
 : (_endTime ?? const TimeOfDay(hour: 23, minute: 0)),
 builder: (pickerCtx, child) => MediaQuery(
 data: MediaQuery.of(pickerCtx).copyWith(alwaysUse24HourFormat: false),
 child: Theme(
 data: Theme.of(pickerCtx).copyWith(
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
 setState(() {
 if (isMainStart) {
 _startTime = picked;
 } else {
 _endTime = picked;
 }
 });
 _saveWorkingHoursToPrefs();
 }
 }

  Future<void> _selectTimeForBreak(BuildContext context, int index, bool isStart) async {
    final initial = isStart ? _breakTimes[index]['start'] : _breakTimes[index]['end'];
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked != null && mounted) {
      final hour = picked.hour;
      final minute = picked.minute;
      final roundedMinute = (minute < 30) ? 0 : 0;
      final roundedTime = TimeOfDay(hour: hour, minute: roundedMinute);
      setState(() {
        if (isStart) {
          _breakTimes[index]['start'] = roundedTime;
        } else {
          _breakTimes[index]['end'] = roundedTime;
        }
      });
      _saveWorkingHoursToPrefs();
    }
  }

  Future<void> _pickImage() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: VSPColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(VSPSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(
                isArabic ? 'إضافة صور للملعب' : 'Add Stadium Photos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Iconsax.gallery_copy, color: VSPColors.accent),
                title: Text(isArabic ? 'اختيار عدة صور من المعرض' : 'Pick multiple photos'),
                subtitle: Text(isArabic ? 'رفع متسلسل تلقائي مع شريط تقدم' : 'Automatic sequential upload with progress'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickMultipleImages();
                },
              ),
              ListTile(
                leading: const Icon(Iconsax.crop_copy, color: VSPColors.accent),
                title: Text(isArabic ? 'صورة واحدة مع ضبط الأبعاد (16:9)' : 'Single photo with 16:9 crop'),
                subtitle: Text(isArabic ? 'أفضل كصورة غلاف رئيسية' : 'Best as main cover photo'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickSingleCroppedImage();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickSingleCroppedImage() async {
    try {
      final picked = await ImagePickService.pick(
        context,
        aspectRatio: CropAspectRatioPreset.ratio16x9,
      );
      if (picked == null) return;
      await _uploadSinglePickedFile(picked);
    } catch (e) {
      debugPrint('Error picking single image: $e');
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> pickedList = await _imagePicker.pickMultiImage();
      if (pickedList.isEmpty) return;

      final total = pickedList.length;
      for (int i = 0; i < total; i++) {
        if (!mounted) break;
        await _uploadSinglePickedFile(
          pickedList[i],
          currentIndex: i + 1,
          totalCount: total,
        );
      }
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
    }
  }

  Future<void> _uploadSinglePickedFile(XFile pickedFile, {int? currentIndex, int? totalCount}) async {
    Timer? progressTimer;
    final imageFile = File(pickedFile.path);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final progressLabel = (currentIndex != null && totalCount != null && totalCount > 1)
        ? (isArabic ? "جارٍ رفع الصورة $currentIndex من $totalCount" : "Uploading photo $currentIndex of $totalCount")
        : null;

    final imageEntry = {
      'file': imageFile,
      'url': null,
      'isUploading': true,
      'progress': 0,
      'statusLabel': progressLabel,
    };
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
          VSPFeedback.showError(context, isArabic ? 'فشل رفع الصورة، يرجى المحاولة ثانية.' : 'Failed to upload photo.');
        }
        return;
      }
      setState(() {
        imageEntry['url'] = url;
        imageEntry['progress'] = 100;
        imageEntry['isUploading'] = false;
      });
      _saveImagesToPrefs();

      // مسح الأثر: حذف الملف المؤقت من الكاش بعد نجاح الرفع
      try {
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (_) {}
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
 _saveStepToPrefs(_currentStep);
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
 isArabic ? 'تجاهل التغييرات؟ ' : 'Discard changes? ',
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
 _saveStepToPrefs(_currentStep);
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
 'start': _formatTime(_startTime, '16:00:00'),
 'end': _formatTime(_endTime, '23:00:00'),
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
 'governorate': _governorate, // Added for filtering
 'pricePerHour': double.tryParse(_priceController.text.trim()) ?? 0.0,
 'players_per_team': int.tryParse(_capacityController.text.trim()) ?? 5,
 'total_field_capacity': (int.tryParse(_capacityController.text.trim()) ?? 5) * 2,
 'deposit_amount': _requireDeposit ? (double.tryParse(_depositController.text.trim()) ?? 0.0) : 0.0,
 'needs_deposit': _requireDeposit,
 'imageUrl': uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
 'images': uploadedUrls,
 'notes': _notesController.text.trim(),
 'features': stadiumFeatures,
 'opening_time': _formatTime(_startTime, '16:00:00'),
 'closing_time': _formatTime(_endTime, '03:00:00'),
 'lat': _latitude,
 'lng': _longitude,
 });
 } else {
 // Create Logic
 final stadiumId = await _databaseService.createStadium(
 name: _nameController.text.trim(),
 location: _locationController.text.trim(),
 governorate: _governorate, // Added for filtering
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
      if (!mounted) return;
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      _showError(isArabic ? 'فشل إنشاء الملعب. يرجى مراجعة البيانات المدخلة وصلاحيات الحساب.' : 'Failed to create stadium. Please check your data or permissions.');
      return;
    }
 // IMMEDIATELY set hasStadium flag so app navigation knows
 
 }
 
 if (mounted) {
 // CONTEXT-FIX: إتمام كافة العمليات غير المتزامنة قبل إغلاق الشاشة
 if (widget.stadiumId == null) {
 await _clearPersistedForm();
 await auth.updateProfile({'hasStadium': true});
 }
 await auth.refreshProfile();

 if (!mounted || !context.mounted) return;
 final l10n = AppLocalizations.of(context)!;
 VSPFeedback.showSuccess(context, l10n.stadiumSubmitSuccess);
 if (context.mounted) {
 Navigator.pop(context); // إغلاق الشاشة يتم في النهاية بأمان
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

 String _formatTime(TimeOfDay? time, String defaultTime24) {
 if (time == null) return defaultTime24;
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
          leading: VSPBackButton(onTap: _previousPage),
          title: Text(AppLocalizations.of(context)!.addStadium, style: Theme.of(context).textTheme.displaySmall),
          centerTitle: true,
          elevation: 0,
          actions: [
            if (widget.stadiumId != null)
              IconButton(
                icon: const Icon(Iconsax.trash_copy, color: VSPColors.error),
                onPressed: () => _showDeleteConfirmationDialog(),
              ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                AddStadiumStepIndicator(
                  currentStep: _currentStep,
                  isEditing: widget.stadiumId != null,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      AddStadiumStep1Details(
                        nameController: _nameController,
                        stadiumPhoneController: _stadiumPhoneController,
                        priceController: _priceController,
                        capacityController: _capacityController,
                        locationController: _locationController,
                        lengthController: _lengthController,
                        widthController: _widthController,
                        notesController: _notesController,
                        selectedSportType: _selectedSportType,
                        startTime: _startTime,
                        endTime: _endTime,
                        isSplitShift: _isSplitShift,
                        breakTimes: _breakTimes,
                        isSplitShiftValid: _isSplitShiftValid,
                        isLocationLoading: _isLocationLoading,
                        isEditing: widget.stadiumId != null,
                        onSelectSport: (val) => setState(() => _selectedSportType = val),
                        onSelectTime: (isMainStart) => _selectTime(context, isMainStart),
                        onToggleSplitShift: _updateIsSplitShift,
                        onSelectBreakTime: (index, isStart) => _selectTimeForBreak(context, index, isStart),
                        onAddBreak: () => setState(() => _breakTimes.add({'start': null, 'end': null})),
                        onRemoveBreak: (index) => setState(() => _breakTimes.removeAt(index)),
                        onOpenMapPicker: _openMapPicker,
                        onAddNoteTemplate: (template) {
                          final currentText = _notesController.text;
                          final prefix = currentText.isEmpty ? '' : '$currentText\n';
                          setState(() => _notesController.text = '$prefix• $template');
                        },
                        onNext: _nextPage,
                      ),
                      AddStadiumStep2Features(
                        seatsController: _seatsController,
                        ballPriceController: _ballPriceController,
                        depositController: _depositController,
                        selectedBathOption: _selectedBathOption,
                        cafeteria: _cafeteria,
                        garage: _garage,
                        changingRoom: _changingRoom,
                        hasBall: _hasBall,
                        requireDeposit: _requireDeposit,
                        onUpdateBathOption: _updateBathOption,
                        onUpdateCafeteria: _updateCafeteria,
                        onUpdateGarage: _updateGarage,
                        onUpdateChangingRoom: _updateChangingRoom,
                        onUpdateHasBall: _updateHasBall,
                        onUpdateRequireDeposit: _updateRequireDeposit,
                        onNext: _nextPage,
                      ),
                      AddStadiumStep3Images(
                        images: _images,
                        isUploading: _isUploading,
                        isSaving: _isSaving,
                        onPickImage: _pickImage,
                        onDeleteImage: (img) async {
                          if (img['url'] != null) {
                            await _storageService.deleteFile(img['url']!);
                          }
                          setState(() => _images.remove(img));
                        },
                        onSubmit: _nextPage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          isArabic ? 'إخفاء وحذف الملعب؟ ' : 'Hide & Delete Stadium? ',
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
        bool success = false;
        try {
          success = await StadiumRepository().deleteStadium(widget.stadiumId!);
        } catch (e) {
          if (e.toString().contains('active_bookings_exist')) {
            if (!mounted) return;
            VSPFeedback.showError(
              context,
              isArabic
                  ? 'لا يمكن حذف الملعب لوجود حجوزات نشطة اليوم أو في المستقبل! قم بإلغائها أو انتظار انتهائها أولاً.'
                  : 'Cannot delete stadium with active bookings today or in the future! Cancel them or wait for completion first.',
            );
            return;
          }
        }

        if (!mounted) return;
        if (success) {
          final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
          final uid = auth.currentUser?.uid;
          if (uid != null) {
            final bool stillHas = await StadiumRepository().checkOwnerHasRemainingStadiums(uid);
            await auth.updateProfile({'hasStadium': stillHas});
          }

          if (mounted) {
            VSPFeedback.showSuccess(
              context,
              isArabic
                  ? 'تم حذف الملعب نهائياً واختفاؤه من التطبيق بنجاح! '
                  : 'Stadium deleted permanently and hidden from app! ',
            );
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            VSPFeedback.showError(
              context,
              isArabic ? 'حدث خطأ أثناء عملية حذف الملعب' : 'Error deleting stadium',
            );
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
