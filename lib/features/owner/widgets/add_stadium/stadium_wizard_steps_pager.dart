import 'package:flutter/material.dart';
import 'add_stadium_step1_details.dart';
import 'add_stadium_step2_features.dart';
import 'add_stadium_step3_images.dart';
import 'stadium_wizard_controllers.dart';
import 'stadium_wizard_features_state.dart';
import 'stadium_wizard_media_coordinator.dart';

/// Encapsulates the 3-step PageView for AddStadiumWizard.
class StadiumWizardStepsPager extends StatelessWidget {
  final PageController pageController;
  final StadiumWizardControllers controllers;
  final StadiumWizardFeaturesState featuresState;
  final String? stadiumId;
  final String? uid;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool isSplitShift;
  final List<Map<String, TimeOfDay?>> breakTimes;
  final bool isSplitShiftValid;
  final bool isLocationLoading;
  final List<Map<String, dynamic>> images;
  final bool isUploading;
  final bool isSaving;

  // Callbacks
  final ValueChanged<String?> onSelectSport;
  final void Function(bool isMainStart) onSelectTime;
  final ValueChanged<bool> onToggleSplitShift;
  final void Function(int index, bool isStart) onSelectBreakTime;
  final VoidCallback onAddBreak;
  final ValueChanged<int> onRemoveBreak;
  final VoidCallback onOpenMapPicker;
  final VoidCallback onOpenManualPicker;
  final ValueChanged<String> onAddNoteTemplate;
  final VoidCallback onNextPage;
  final VoidCallback onStateChanged;

  const StadiumWizardStepsPager({
    super.key,
    required this.pageController,
    required this.controllers,
    required this.featuresState,
    required this.stadiumId,
    required this.uid,
    required this.startTime,
    required this.endTime,
    required this.isSplitShift,
    required this.breakTimes,
    required this.isSplitShiftValid,
    required this.isLocationLoading,
    required this.images,
    required this.isUploading,
    required this.isSaving,
    required this.onSelectSport,
    required this.onSelectTime,
    required this.onToggleSplitShift,
    required this.onSelectBreakTime,
    required this.onAddBreak,
    required this.onRemoveBreak,
    required this.onOpenMapPicker,
    required this.onOpenManualPicker,
    required this.onAddNoteTemplate,
    required this.onNextPage,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        AddStadiumStep1Details(
          nameController: controllers.name,
          stadiumPhoneController: controllers.phone,
          priceController: controllers.price,
          capacityController: controllers.capacity,
          locationController: controllers.location,
          lengthController: controllers.length,
          widthController: controllers.width,
          notesController: controllers.notes,
          selectedSportType: featuresState.selectedSportType,
          startTime: startTime,
          endTime: endTime,
          isSplitShift: isSplitShift,
          breakTimes: breakTimes,
          isSplitShiftValid: isSplitShiftValid,
          isLocationLoading: isLocationLoading,
          isEditing: stadiumId != null,
          onSelectSport: onSelectSport,
          onSelectTime: onSelectTime,
          onToggleSplitShift: onToggleSplitShift,
          onSelectBreakTime: onSelectBreakTime,
          onAddBreak: onAddBreak,
          onRemoveBreak: onRemoveBreak,
          onOpenMapPicker: onOpenMapPicker,
          onOpenManualPicker: onOpenManualPicker,
          onAddNoteTemplate: onAddNoteTemplate,
          onNext: onNextPage,
        ),
        AddStadiumStep2Features(
          seatsController: controllers.seats,
          ballPriceController: controllers.ballPrice,
          depositController: controllers.deposit,
          selectedBathOption: featuresState.selectedBathOption,
          cafeteria: featuresState.cafeteria,
          garage: featuresState.garage,
          changingRoom: featuresState.changingRoom,
          hasBall: featuresState.hasBall,
          requireDeposit: featuresState.requireDeposit,
          onUpdateBathOption: (val) {
            featuresState.updateBathOption(val, uid: uid, isEditing: stadiumId != null);
            onStateChanged();
          },
          onUpdateCafeteria: (val) {
            featuresState.updateCafeteria(val, uid: uid, isEditing: stadiumId != null);
            onStateChanged();
          },
          onUpdateGarage: (val) {
            featuresState.updateGarage(val, uid: uid, isEditing: stadiumId != null);
            onStateChanged();
          },
          onUpdateChangingRoom: (val) {
            featuresState.updateChangingRoom(val, uid: uid, isEditing: stadiumId != null);
            onStateChanged();
          },
          onUpdateHasBall: (val) {
            featuresState.updateHasBall(val, uid: uid, isEditing: stadiumId != null);
            onStateChanged();
          },
          onUpdateRequireDeposit: (val) {
            featuresState.updateRequireDeposit(val, uid: uid, isEditing: stadiumId != null);
            if (!val) controllers.deposit.clear();
            onStateChanged();
          },
          onNext: onNextPage,
        ),
        AddStadiumStep3Images(
          images: images,
          isUploading: isUploading,
          isSaving: isSaving,
          onPickImage: () => StadiumWizardMediaCoordinator.pickAndUpload(
            context: context,
            images: images,
            stadiumId: stadiumId,
            uid: uid,
            onStateChanged: onStateChanged,
          ),
          onDeleteImage: (img) => StadiumWizardMediaCoordinator.deleteImage(
            image: img,
            images: images,
            stadiumId: stadiumId,
            uid: uid,
            onStateChanged: onStateChanged,
          ),
          onSubmit: onNextPage,
        ),
      ],
    );
  }
}
