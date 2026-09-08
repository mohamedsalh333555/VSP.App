import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/vsp_back_button.dart';

import '../widgets/add_stadium/add_stadium_location_picker_sheet.dart';
import '../widgets/add_stadium/add_stadium_step_indicator.dart';
import '../widgets/add_stadium/add_stadium_step1_details.dart';
import '../widgets/add_stadium/add_stadium_step2_features.dart';
import '../widgets/add_stadium/add_stadium_step3_images.dart';
import '../widgets/add_stadium/stadium_wizard_dialogs.dart';
import '../widgets/add_stadium/stadium_wizard_draft_service.dart';
import '../widgets/add_stadium/stadium_wizard_image_service.dart';
import '../widgets/add_stadium/stadium_wizard_payload_builder.dart';
import '../widgets/add_stadium/stadium_wizard_time_utils.dart';
import '../widgets/add_stadium/stadium_wizard_validator.dart';

class AddStadiumWizard extends StatefulWidget {
  final String? stadiumId;
  const AddStadiumWizard({super.key, this.stadiumId});

  @override
  State<AddStadiumWizard> createState() => _AddStadiumWizardState();
}

class _AddStadiumWizardState extends State<AddStadiumWizard> {
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
  final _ballPriceController = TextEditingController();
  final _depositController = TextEditingController();

  // Features state
  bool? _hasBall;
  bool? _cafeteria;
  bool? _garage;
  bool? _changingRoom;
  String? _selectedSportType;
  String? _selectedFloorType;
  String? _selectedBathOption;

  // Appointment / Working hours state
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSplitShift = false;
  List<Map<String, TimeOfDay?>> _breakTimes = [];

  // Media & Geocoding state
  final List<Map<String, dynamic>> _images = [];
  final bool _isUploading = false;
  bool _isLocationLoading = false;
  bool _isSaving = false;
  double? _latitude;
  double? _longitude;
  String? _governorate;
  bool _requireDeposit = false;

  final StadiumRepository _databaseService = StadiumRepository();

  String? get _uid {
    try {
      final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
      return auth.userModel?.uid ?? auth.currentUser?.uid ?? auth.firebaseUser?.id;
    } catch (_) {
      return null;
    }
  }

  bool get _isSplitShiftValid => StadiumWizardTimeUtils.isSplitShiftValid(
        startTime: _startTime,
        endTime: _endTime,
        isSplitShift: _isSplitShift,
        breakTimes: _breakTimes,
      );

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

  Future<void> _loadPersistedForm() async {
    if (widget.stadiumId != null) return;
    try {
      final draft = await StadiumWizardDraftService.loadDraft(_uid);
      if (!mounted) return;

      setState(() {
        _nameController.text = draft.name;
        _locationController.text = draft.location;
        _priceController.text = draft.price;
        _capacityController.text = draft.capacity;
        _stadiumPhoneController.text = draft.phone;
        _notesController.text = draft.notes;
        _lengthController.text = draft.length;
        _widthController.text = draft.width;
        _seatsController.text = draft.seats;
        _ballPriceController.text = draft.ballPrice;
        _depositController.text = draft.deposit;

        _governorate = draft.governorate;
        _selectedSportType = draft.sportType;
        _selectedFloorType = draft.floorType;
        _selectedBathOption = draft.bathOption;

        _cafeteria = draft.cafeteria;
        _garage = draft.garage;
        _changingRoom = draft.changingRoom;
        _hasBall = draft.hasBall;
        _requireDeposit = draft.requireDeposit;
        _isSplitShift = draft.isSplitShift;

        _latitude = draft.latitude;
        _longitude = draft.longitude;
        _startTime = draft.startTime;
        _endTime = draft.endTime;
        _breakTimes = List.from(draft.breakTimes);

        _images.clear();
        _images.addAll(draft.images);

        if (draft.currentStep > 0 && draft.currentStep <= 2) {
          _currentStep = draft.currentStep;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(draft.currentStep);
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading persisted form data: $e');
    }
  }

  void _setupAutoSaveListeners() {
    _nameController.addListener(() => StadiumWizardDraftService.saveString(_uid, 'name', _nameController.text));
    _locationController.addListener(() => StadiumWizardDraftService.saveString(_uid, 'location', _locationController.text));
    _priceController.addListener(() => StadiumWizardDraftService.saveString(_uid, 'price', _priceController.text));
    _capacityController.addListener(() => StadiumWizardDraftService.saveString(_uid, 'capacity', _capacityController.text));
    _stadiumPhoneController.addListener(() => StadiumWizardDraftService.saveString(_uid, 'phone', _stadiumPhoneController.text));
    _notesController.addListener(() => StadiumWizardDraftService.saveString(_uid, 'notes', _notesController.text));
    _lengthController.addListener(() => StadiumWizardDraftService.saveString(_uid, 'length', _lengthController.text));
    _widthController.addListener(() => StadiumWizardDraftService.saveString(_uid, 'width', _widthController.text));
    _seatsController.addListener(() => StadiumWizardDraftService.saveString(_uid, 'seats', _seatsController.text));
    _ballPriceController.addListener(() => StadiumWizardDraftService.saveString(_uid, 'ball_price', _ballPriceController.text));
    _depositController.addListener(() => StadiumWizardDraftService.saveString(_uid, 'deposit', _depositController.text));
  }

  void _updateBathOption(bool val) {
    setState(() => _selectedBathOption = val ? 'Yes' : 'No');
    if (widget.stadiumId == null) {
      StadiumWizardDraftService.saveString(_uid, 'bath_option', _selectedBathOption!);
    }
  }

  void _updateCafeteria(bool val) {
    setState(() => _cafeteria = val);
    if (widget.stadiumId == null) {
      StadiumWizardDraftService.saveBool(_uid, 'cafeteria', val);
    }
  }

  void _updateGarage(bool val) {
    setState(() => _garage = val);
    if (widget.stadiumId == null) {
      StadiumWizardDraftService.saveBool(_uid, 'garage', val);
    }
  }

  void _updateChangingRoom(bool val) {
    setState(() => _changingRoom = val);
    if (widget.stadiumId == null) {
      StadiumWizardDraftService.saveBool(_uid, 'changing_room', val);
    }
  }

  void _updateHasBall(bool val) {
    setState(() => _hasBall = val);
    if (widget.stadiumId == null) {
      StadiumWizardDraftService.saveBool(_uid, 'has_ball', val);
    }
  }

  void _updateRequireDeposit(bool val) {
    setState(() {
      _requireDeposit = val;
      if (!val) _depositController.clear();
    });
    if (widget.stadiumId == null) {
      StadiumWizardDraftService.saveBool(_uid, 'require_deposit', val);
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
      StadiumWizardDraftService.saveBool(_uid, 'is_split_shift', val);
    }
  }

  Future<void> _loadStadiumData() async {
    try {
      final data = await _databaseService.getStadiumSnapshot(widget.stadiumId!);
      if (data != null && mounted) {
        _nameController.text = data['name'] ?? '';
        _locationController.text = data['location'] ?? '';
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
          _startTime = StadiumWizardTimeUtils.parseTime(workingHours['start']);
          _endTime = StadiumWizardTimeUtils.parseTime(workingHours['end']);
        }

        _isSplitShift = features['isSplitShift'] ?? false;
        _breakTimes = [];
        if (features['breakTimes'] != null) {
          final list = features['breakTimes'] as List;
          for (var item in list) {
            if (item is Map) {
              _breakTimes.add({
                'start': StadiumWizardTimeUtils.parseTime(item['start']?.toString()),
                'end': StadiumWizardTimeUtils.parseTime(item['end']?.toString()),
              });
            }
          }
        }
        if (_breakTimes.isEmpty && features['breakTime'] != null) {
          final breakTime = features['breakTime'] as Map<String, dynamic>;
          _breakTimes.add({
            'start': StadiumWizardTimeUtils.parseTime(breakTime['start']?.toString()),
            'end': StadiumWizardTimeUtils.parseTime(breakTime['end']?.toString()),
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

        _images.clear();
        for (var url in allImages) {
          _images.add({'file': null, 'url': url, 'isUploading': false});
        }

        _notesController.text = data['notes'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading stadium data: $e');
    }
  }

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
          StadiumWizardDraftService.saveDouble(_uid, 'lat', result.latitude);
          StadiumWizardDraftService.saveDouble(_uid, 'lng', result.longitude);
          StadiumWizardDraftService.saveString(_uid, 'location', result.address);
          if (result.governorate != null) {
            StadiumWizardDraftService.saveString(_uid, 'governorate', result.governorate!);
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
    final initial = isMainStart
        ? (_startTime ?? const TimeOfDay(hour: 16, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 23, minute: 0));

    final picked = await StadiumWizardTimeUtils.selectTime(context, initialTime: initial);
    if (picked != null && mounted) {
      setState(() {
        if (isMainStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
      if (widget.stadiumId == null) {
        StadiumWizardDraftService.saveWorkingHours(
          _uid,
          startTime: _startTime,
          endTime: _endTime,
          breakTimes: _breakTimes,
        );
      }
    }
  }

  Future<void> _selectTimeForBreak(BuildContext context, int index, bool isStart) async {
    final initial = isStart ? _breakTimes[index]['start'] : _breakTimes[index]['end'];
    final picked = await StadiumWizardTimeUtils.selectTime(
      context,
      initialTime: initial ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked != null && mounted) {
      final hour = picked.hour;
      final minute = (picked.minute < 30) ? 0 : 0;
      final roundedTime = TimeOfDay(hour: hour, minute: minute);
      setState(() {
        if (isStart) {
          _breakTimes[index]['start'] = roundedTime;
        } else {
          _breakTimes[index]['end'] = roundedTime;
        }
      });
      if (widget.stadiumId == null) {
        StadiumWizardDraftService.saveWorkingHours(
          _uid,
          startTime: _startTime,
          endTime: _endTime,
          breakTimes: _breakTimes,
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final pickType = await StadiumWizardImageService.showImageSourceModal(context);
    if (pickType == null || !mounted) return;

    if (pickType == StadiumImagePickType.single16x9) {
      final xFile = await StadiumWizardImageService.pickSingleCroppedImage(context);
      if (xFile != null && mounted) {
        await _uploadImage(xFile);
      }
    } else if (pickType == StadiumImagePickType.multiple) {
      final files = await StadiumWizardImageService.pickMultipleImages();
      if (files.isEmpty || !mounted) return;

      final total = files.length;
      for (int i = 0; i < total; i++) {
        if (!mounted) break;
        await _uploadImage(files[i], currentIndex: i + 1, totalCount: total);
      }
    }
  }

  Future<void> _uploadImage(XFile xFile, {int? currentIndex, int? totalCount}) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final progressLabel = (currentIndex != null && totalCount != null && totalCount > 1)
        ? (isArabic ? "جارٍ رفع الصورة $currentIndex من $totalCount" : "Uploading photo $currentIndex of $totalCount")
        : null;

    final imageEntry = <String, dynamic>{
      'file': null,
      'url': null,
      'isUploading': true,
      'progress': 10,
      'statusLabel': progressLabel,
    };

    setState(() => _images.add(imageEntry));

    final url = await StadiumWizardImageService.uploadImageFile(
      xFile: xFile,
      onProgress: (progress) {
        if (mounted) {
          setState(() => imageEntry['progress'] = progress);
        }
      },
    );

    if (!mounted) return;

    if (url == null) {
      setState(() => _images.remove(imageEntry));
      VSPFeedback.showError(context, isArabic ? 'فشل رفع الصورة، يرجى المحاولة ثانية.' : 'Failed to upload photo.');
      return;
    }

    setState(() {
      imageEntry['url'] = url;
      imageEntry['progress'] = 100;
      imageEntry['isUploading'] = false;
    });

    if (widget.stadiumId == null) {
      StadiumWizardDraftService.saveImages(_uid, _images);
    }
  }

  void _nextPage() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_currentStep == 0) {
      final error = StadiumWizardValidator.validateStep0(
        location: _locationController.text,
        name: _nameController.text,
        stadiumPhone: _stadiumPhoneController.text,
        sportType: _selectedSportType,
        price: _priceController.text,
        startTime: _startTime,
        endTime: _endTime,
        isSplitShift: _isSplitShift,
        breakTimes: _breakTimes,
        isArabic: isArabic,
      );
      if (error != null) {
        _showError(error);
        return;
      }
    } else if (_currentStep == 1) {
      final l10n = AppLocalizations.of(context)!;
      final error = StadiumWizardValidator.validateStep1(
        selectedBathOption: _selectedBathOption,
        cafeteria: _cafeteria,
        hasBall: _hasBall,
        ballPriceText: _ballPriceController.text,
        requireDeposit: _requireDeposit,
        depositText: _depositController.text,
        priceText: _priceController.text,
        isArabic: isArabic,
        selectFeaturesError: l10n.selectFeaturesError,
        ballPriceMinError: l10n.ballPriceMinError,
      );
      if (error != null) {
        _showError(error);
        return;
      }
    } else if (_currentStep == 2) {
      final error = StadiumWizardValidator.validateStep2(
        images: _images,
        stadiumId: widget.stadiumId,
        uploadPhotoError: AppLocalizations.of(context)!.uploadPhotoError,
      );
      if (error != null) {
        _showError(error);
        return;
      }
      _saveStadium();
      return;
    }

    if (_currentStep < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
      if (widget.stadiumId == null) {
        StadiumWizardDraftService.saveStep(_uid, _currentStep);
      }
    }
  }

  void _previousPage() async {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
      if (widget.stadiumId == null) {
        StadiumWizardDraftService.saveStep(_uid, _currentStep);
      }
    } else {
      final shouldLeave = await StadiumWizardDialogs.showDiscardConfirmation(context);
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
      final user = auth.firebaseUser;

      if (user == null) {
        _showError("Authentication lost. Please login again.");
        return;
      }

      final stadiumFeatures = StadiumWizardPayloadBuilder.buildFeatures(
        stadiumPhone: _stadiumPhoneController.text,
        sportType: _selectedSportType,
        floorType: _selectedFloorType,
        bathOption: _selectedBathOption,
        cafeteria: _cafeteria,
        garage: _garage,
        changingRoom: _changingRoom,
        seats: _seatsController.text,
        length: _lengthController.text,
        width: _widthController.text,
        hasBall: _hasBall ?? false,
        ballPrice: double.tryParse(_ballPriceController.text) ?? 0.0,
        startTime: _startTime,
        endTime: _endTime,
        isSplitShift: _isSplitShift,
        breakTimes: _breakTimes,
        uploadedUrls: uploadedUrls,
      );

      if (widget.stadiumId != null) {
        final updatePayload = StadiumWizardPayloadBuilder.buildUpdatePayload(
          name: _nameController.text,
          location: _locationController.text,
          governorate: _governorate,
          pricePerHour: double.tryParse(_priceController.text.trim()) ?? 0.0,
          capacity: int.tryParse(_capacityController.text.trim()) ?? 5,
          requireDeposit: _requireDeposit,
          depositAmount: double.tryParse(_depositController.text.trim()) ?? 0.0,
          uploadedUrls: uploadedUrls,
          notes: _notesController.text,
          features: stadiumFeatures,
          startTime: _startTime,
          endTime: _endTime,
          latitude: _latitude,
          longitude: _longitude,
        );
        await _databaseService.updateStadium(widget.stadiumId!, updatePayload);
      } else {
        final stadiumId = await _databaseService.createStadium(
          name: _nameController.text.trim(),
          location: _locationController.text.trim(),
          governorate: _governorate,
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
      }

      if (mounted) {
        if (widget.stadiumId == null) {
          await StadiumWizardDraftService.clearDraft(_uid);
          await auth.updateProfile({'hasStadium': true});
        }
        await auth.refreshProfile();

        if (!mounted || !context.mounted) return;
        final l10n = AppLocalizations.of(context)!;
        VSPFeedback.showSuccess(context, l10n.stadiumSubmitSuccess);
        if (context.mounted) {
          Navigator.pop(context);
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
        final shouldLeave = await StadiumWizardDialogs.showDiscardConfirmation(context);
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
                onPressed: () => StadiumWizardDialogs.showDeleteStadiumDialog(
                  context,
                  stadiumId: widget.stadiumId!,
                  onDeleted: () {
                    if (mounted) Navigator.pop(context);
                  },
                ),
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
                            await StadiumWizardImageService.deleteUploadedImage(img['url']!);
                          }
                          if (mounted) {
                            setState(() => _images.remove(img));
                            if (widget.stadiumId == null) {
                              StadiumWizardDraftService.saveImages(_uid, _images);
                            }
                          }
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
}
