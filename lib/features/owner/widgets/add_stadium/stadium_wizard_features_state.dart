import 'stadium_wizard_data_loader.dart';
import 'stadium_wizard_draft_service.dart';

/// Encapsulates feature checkbox and option state for the stadium wizard.
class StadiumWizardFeaturesState {
  bool? hasBall;
  bool? cafeteria;
  bool? garage;
  bool? changingRoom;
  String? selectedSportType;
  String? selectedFloorType;
  String? selectedBathOption;
  bool requireDeposit = false;

  /// Populates state from restored draft.
  void populateFromDraft(StadiumDraftData draft) {
    selectedSportType = draft.sportType;
    selectedFloorType = draft.floorType;
    selectedBathOption = draft.bathOption;
    cafeteria = draft.cafeteria;
    garage = draft.garage;
    changingRoom = draft.changingRoom;
    hasBall = draft.hasBall;
    requireDeposit = draft.requireDeposit;
  }

  /// Populates state from loaded database stadium model.
  void populateFromLoaded(StadiumLoadedData loaded) {
    requireDeposit = loaded.requireDeposit;
    selectedFloorType = loaded.floorType;
    selectedSportType = loaded.sportType;
    selectedBathOption = loaded.bathOption;
    cafeteria = loaded.cafeteria;
    garage = loaded.garage;
    changingRoom = loaded.changingRoom;
    hasBall = loaded.hasBall;
  }

  /// Updates bath option and persists if not in editing mode.
  void updateBathOption(bool val, {required String? uid, required bool isEditing}) {
    selectedBathOption = val ? 'Yes' : 'No';
    if (!isEditing) {
      StadiumWizardDraftService.saveString(uid, 'bath_option', selectedBathOption!);
    }
  }

  /// Updates cafeteria option and persists if not in editing mode.
  void updateCafeteria(bool val, {required String? uid, required bool isEditing}) {
    cafeteria = val;
    if (!isEditing) {
      StadiumWizardDraftService.saveBool(uid, 'cafeteria', val);
    }
  }

  /// Updates garage option and persists if not in editing mode.
  void updateGarage(bool val, {required String? uid, required bool isEditing}) {
    garage = val;
    if (!isEditing) {
      StadiumWizardDraftService.saveBool(uid, 'garage', val);
    }
  }

  /// Updates changing room option and persists if not in editing mode.
  void updateChangingRoom(bool val, {required String? uid, required bool isEditing}) {
    changingRoom = val;
    if (!isEditing) {
      StadiumWizardDraftService.saveBool(uid, 'changing_room', val);
    }
  }

  /// Updates ball option and persists if not in editing mode.
  void updateHasBall(bool val, {required String? uid, required bool isEditing}) {
    hasBall = val;
    if (!isEditing) {
      StadiumWizardDraftService.saveBool(uid, 'has_ball', val);
    }
  }

  /// Updates require deposit option and persists if not in editing mode.
  void updateRequireDeposit(bool val, {required String? uid, required bool isEditing}) {
    requireDeposit = val;
    if (!isEditing) {
      StadiumWizardDraftService.saveBool(uid, 'require_deposit', val);
    }
  }
}
