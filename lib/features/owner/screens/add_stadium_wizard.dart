import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/vsp_back_button.dart';

import '../widgets/add_stadium/add_stadium_step_indicator.dart';
import '../widgets/add_stadium/stadium_wizard_controllers.dart';
import '../widgets/add_stadium/stadium_wizard_data_loader.dart';
import '../widgets/add_stadium/stadium_wizard_dialogs.dart';
import '../widgets/add_stadium/stadium_wizard_draft_service.dart';
import '../widgets/add_stadium/stadium_wizard_features_state.dart';
import '../widgets/add_stadium/stadium_wizard_location_coordinator.dart';
import '../widgets/add_stadium/stadium_wizard_steps_pager.dart';
import '../widgets/add_stadium/stadium_wizard_submit_service.dart';
import '../widgets/add_stadium/stadium_wizard_time_coordinator.dart';
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

  // Encapsulated Form Controllers and Feature Options
  final _c = StadiumWizardControllers();
  final _f = StadiumWizardFeaturesState();

  // Shift and Break hours
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSplitShift = false;
  List<Map<String, TimeOfDay?>> _breakTimes = [];

  // Media, Geocoding, and UI states
  final List<Map<String, dynamic>> _images = [];
  final bool _isUploading = false;
  bool _isLocationLoading = false;
  bool _isSaving = false;
  double? _latitude;
  double? _longitude;
  String? _governorate;

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
      _loadPersistedForm().then((_) => _c.setupAutoSave(_uid));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedForm() async {
    if (widget.stadiumId != null) return;
    try {
      final draft = await StadiumWizardDraftService.loadDraft(_uid);
      if (!mounted) return;

      setState(() {
        _c.populateFromDraft(draft);
        _f.populateFromDraft(draft);

        _governorate = draft.governorate;
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

  void _updateSplitShift(bool val) {
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
    final loaded = await StadiumWizardDataLoader.load(
      widget.stadiumId!,
      repository: _databaseService,
    );
    if (loaded != null && mounted) {
      setState(() {
        _c.populateFromLoaded(loaded);
        _f.populateFromLoaded(loaded);

        _startTime = loaded.startTime;
        _endTime = loaded.endTime;
        _isSplitShift = loaded.isSplitShift;
        _breakTimes = List.from(loaded.breakTimes);
        _images.clear();
        _images.addAll(loaded.images);
      });
    }
  }

  Future<void> _openMapPicker() async {
    setState(() => _isLocationLoading = true);
    try {
      final result = await StadiumWizardLocationCoordinator.pickLocation(
        context,
        currentLat: _latitude,
        currentLng: _longitude,
        uid: _uid,
        isEditing: widget.stadiumId != null,
      );
      if (result != null && mounted) {
        setState(() {
          _latitude = result.latitude;
          _longitude = result.longitude;
          _c.location.text = result.address;
          if (result.governorate != null) {
            _governorate = result.governorate;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _selectTime(BuildContext context, bool isMainStart) async {
    final picked = await StadiumWizardTimeCoordinator.selectShiftTime(
      context,
      isMainStart: isMainStart,
      startTime: _startTime,
      endTime: _endTime,
      breakTimes: _breakTimes,
      uid: _uid,
      stadiumId: widget.stadiumId,
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
    final picked = await StadiumWizardTimeCoordinator.selectBreakTime(
      context,
      index: index,
      isStart: isStart,
      breakTimes: _breakTimes,
      startTime: _startTime,
      endTime: _endTime,
      uid: _uid,
      stadiumId: widget.stadiumId,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _breakTimes[index]['start'] = picked;
        } else {
          _breakTimes[index]['end'] = picked;
        }
      });
    }
  }

  void _nextPage() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_currentStep == 0) {
      final error = StadiumWizardValidator.validateStep0(
        location: _c.location.text,
        name: _c.name.text,
        stadiumPhone: _c.phone.text,
        sportType: _f.selectedSportType,
        price: _c.price.text,
        startTime: _startTime,
        endTime: _endTime,
        isSplitShift: _isSplitShift,
        breakTimes: _breakTimes,
        isArabic: isArabic,
      );
      if (error != null) {
        VSPFeedback.showError(context, error);
        return;
      }
    } else if (_currentStep == 1) {
      final l10n = AppLocalizations.of(context)!;
      final error = StadiumWizardValidator.validateStep1(
        selectedBathOption: _f.selectedBathOption,
        cafeteria: _f.cafeteria,
        hasBall: _f.hasBall,
        ballPriceText: _c.ballPrice.text,
        requireDeposit: _f.requireDeposit,
        depositText: _c.deposit.text,
        priceText: _c.price.text,
        isArabic: isArabic,
        selectFeaturesError: l10n.selectFeaturesError,
        ballPriceMinError: l10n.ballPriceMinError,
      );
      if (error != null) {
        VSPFeedback.showError(context, error);
        return;
      }
    } else if (_currentStep == 2) {
      final error = StadiumWizardValidator.validateStep2(
        images: _images,
        stadiumId: widget.stadiumId,
        uploadPhotoError: AppLocalizations.of(context)!.uploadPhotoError,
      );
      if (error != null) {
        VSPFeedback.showError(context, error);
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
    setState(() => _isSaving = true);
    try {
      await StadiumWizardSubmitService.submit(
        context: context,
        auth: auth,
        databaseService: _databaseService,
        stadiumId: widget.stadiumId,
        name: _c.name.text,
        location: _c.location.text,
        governorate: _governorate,
        priceText: _c.price.text,
        capacityText: _c.capacity.text,
        depositText: _c.deposit.text,
        requireDeposit: _f.requireDeposit,
        notes: _c.notes.text,
        stadiumPhone: _c.phone.text,
        sportType: _f.selectedSportType,
        floorType: _f.selectedFloorType,
        bathOption: _f.selectedBathOption,
        cafeteria: _f.cafeteria,
        garage: _f.garage,
        changingRoom: _f.changingRoom,
        seats: _c.seats.text,
        length: _c.length.text,
        width: _c.width.text,
        hasBall: _f.hasBall ?? false,
        ballPriceText: _c.ballPrice.text,
        startTime: _startTime,
        endTime: _endTime,
        isSplitShift: _isSplitShift,
        breakTimes: _breakTimes,
        images: _images,
        latitude: _latitude,
        longitude: _longitude,
        uid: _uid,
      );
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
                  child: StadiumWizardStepsPager(
                    pageController: _pageController,
                    controllers: _c,
                    featuresState: _f,
                    stadiumId: widget.stadiumId,
                    uid: _uid,
                    startTime: _startTime,
                    endTime: _endTime,
                    isSplitShift: _isSplitShift,
                    breakTimes: _breakTimes,
                    isSplitShiftValid: _isSplitShiftValid,
                    isLocationLoading: _isLocationLoading,
                    images: _images,
                    isUploading: _isUploading,
                    isSaving: _isSaving,
                    onSelectSport: (val) => setState(() => _f.selectedSportType = val),
                    onSelectTime: (isMainStart) => _selectTime(context, isMainStart),
                    onToggleSplitShift: _updateSplitShift,
                    onSelectBreakTime: (index, isStart) => _selectTimeForBreak(context, index, isStart),
                    onAddBreak: () => setState(() => _breakTimes.add({'start': null, 'end': null})),
                    onRemoveBreak: (index) => setState(() => _breakTimes.removeAt(index)),
                    onOpenMapPicker: _openMapPicker,
                    onAddNoteTemplate: (template) {
                      final currentText = _c.notes.text;
                      final prefix = currentText.isEmpty ? '' : '$currentText\n';
                      setState(() => _c.notes.text = '$prefix• $template');
                    },
                    onNextPage: _nextPage,
                    onStateChanged: () {
                      if (mounted) setState(() {});
                    },
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
