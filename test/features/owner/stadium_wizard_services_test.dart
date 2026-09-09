import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_controllers.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_data_loader.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_draft_service.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_features_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StadiumWizardControllers Tests', () {
    test('populateFromDraft correctly assigns controller values', () {
      final controllers = StadiumWizardControllers();
      const draft = StadiumDraftData(
        name: 'Camp Nou',
        location: 'Barcelona',
        price: '250',
        capacity: '14',
        phone: '01012345678',
        notes: 'Special grass',
        length: '60',
        width: '40',
        seats: '20',
        ballPrice: '30',
        deposit: '100',
      );

      controllers.populateFromDraft(draft);

      expect(controllers.name.text, 'Camp Nou');
      expect(controllers.location.text, 'Barcelona');
      expect(controllers.price.text, '250');
      expect(controllers.capacity.text, '14');
      expect(controllers.phone.text, '01012345678');
      expect(controllers.notes.text, 'Special grass');
      expect(controllers.length.text, '60');
      expect(controllers.width.text, '40');
      expect(controllers.seats.text, '20');
      expect(controllers.ballPrice.text, '30');
      expect(controllers.deposit.text, '100');

      controllers.dispose();
    });

    test('populateFromLoaded correctly assigns loaded stadium record', () {
      final controllers = StadiumWizardControllers();
      const loaded = StadiumLoadedData(
        name: 'Anfield',
        location: 'Liverpool',
        price: '300',
        capacity: '16',
        deposit: '50',
        requireDeposit: true,
        phone: '01122334455',
        floorType: 'Natural',
        sportType: 'Football',
        bathOption: 'Yes',
        cafeteria: true,
        garage: false,
        changingRoom: true,
        seats: '30',
        length: '70',
        width: '50',
        hasBall: true,
        ballPrice: '40',
        startTime: TimeOfDay(hour: 16, minute: 0),
        endTime: TimeOfDay(hour: 23, minute: 0),
        isSplitShift: false,
        breakTimes: [],
        images: [],
        notes: 'Red turf',
      );

      controllers.populateFromLoaded(loaded);

      expect(controllers.name.text, 'Anfield');
      expect(controllers.location.text, 'Liverpool');
      expect(controllers.price.text, '300');
      expect(controllers.capacity.text, '16');
      expect(controllers.deposit.text, '50');
      expect(controllers.phone.text, '01122334455');
      expect(controllers.seats.text, '30');
      expect(controllers.length.text, '70');
      expect(controllers.width.text, '50');
      expect(controllers.ballPrice.text, '40');
      expect(controllers.notes.text, 'Red turf');

      controllers.dispose();
    });
  });

  group('StadiumWizardFeaturesState Tests', () {
    test('populateFromDraft and populateFromLoaded populate features', () {
      final features = StadiumWizardFeaturesState();
      const draft = StadiumDraftData(
        sportType: 'Football',
        floorType: 'Artificial',
        bathOption: 'Yes',
        cafeteria: true,
        garage: true,
        changingRoom: false,
        hasBall: true,
        requireDeposit: true,
      );

      features.populateFromDraft(draft);

      expect(features.selectedSportType, 'Football');
      expect(features.selectedFloorType, 'Artificial');
      expect(features.selectedBathOption, 'Yes');
      expect(features.cafeteria, isTrue);
      expect(features.garage, isTrue);
      expect(features.changingRoom, isFalse);
      expect(features.hasBall, isTrue);
      expect(features.requireDeposit, isTrue);
    });

    test('update methods mutate state and persist', () {
      final features = StadiumWizardFeaturesState();

      features.updateBathOption(true, uid: 'user_1', isEditing: false);
      expect(features.selectedBathOption, 'Yes');

      features.updateCafeteria(true, uid: 'user_1', isEditing: false);
      expect(features.cafeteria, isTrue);

      features.updateGarage(false, uid: 'user_1', isEditing: false);
      expect(features.garage, isFalse);

      features.updateChangingRoom(true, uid: 'user_1', isEditing: false);
      expect(features.changingRoom, isTrue);

      features.updateHasBall(false, uid: 'user_1', isEditing: false);
      expect(features.hasBall, isFalse);

      features.updateRequireDeposit(true, uid: 'user_1', isEditing: false);
      expect(features.requireDeposit, isTrue);
    });
  });
}
