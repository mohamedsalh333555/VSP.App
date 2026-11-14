import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/add_stadium_step2_features.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_draft_service.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_features_state.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_payload_builder.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('owner service choices survive draft restore and reach payload',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final features = StadiumWizardFeaturesState();
    final seats = TextEditingController();
    final ballPrice = TextEditingController();
    final deposit = TextEditingController();
    addTearDown(() {
      seats.dispose();
      ballPrice.dispose();
      deposit.dispose();
    });

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: StatefulBuilder(builder: (context, refresh) {
        void update(void Function() action) => refresh(action);
        return AddStadiumStep2Features(
          seatsController: seats,
          ballPriceController: ballPrice,
          depositController: deposit,
          selectedBathOption: features.selectedBathOption,
          cafeteria: features.cafeteria,
          garage: features.garage,
          changingRoom: features.changingRoom,
          hasBall: features.hasBall,
          requireDeposit: features.requireDeposit,
          onUpdateBathOption: (value) => update(() => features.updateBathOption(value, uid: 'owner-1', isEditing: false)),
          onUpdateCafeteria: (value) => update(() => features.updateCafeteria(value, uid: 'owner-1', isEditing: false)),
          onUpdateGarage: (value) => update(() => features.updateGarage(value, uid: 'owner-1', isEditing: false)),
          onUpdateChangingRoom: (value) => update(() => features.updateChangingRoom(value, uid: 'owner-1', isEditing: false)),
          onUpdateHasBall: (value) => update(() => features.updateHasBall(value, uid: 'owner-1', isEditing: false)),
          onUpdateRequireDeposit: (value) => update(() => features.updateRequireDeposit(value, uid: 'owner-1', isEditing: false)),
          onNext: () {},
        );
      })),
    ));

    final cafeteriaRow = find.ancestor(
      of: find.text('Cafeteria'), matching: find.byType(Row),
    ).first;
    await tester.tap(find.descendant(of: cafeteriaRow, matching: find.text('Yes')));
    await tester.pump();
    final garageRow = find.ancestor(
      of: find.text('Garage'), matching: find.byType(Row),
    ).first;
    await tester.tap(find.descendant(of: garageRow, matching: find.text('No')));
    await tester.pump();

    expect(features.cafeteria, isTrue);
    expect(features.garage, isFalse);
    final draft = await StadiumWizardDraftService.loadDraft('owner-1');
    final restored = StadiumWizardFeaturesState()..populateFromDraft(draft);
    expect(restored.cafeteria, isTrue);
    expect(restored.garage, isFalse);

    final payload = StadiumWizardPayloadBuilder.buildFeatures(
      stadiumPhone: '01000000000',
      sportType: 'Football',
      floorType: 'Artificial',
      bathOption: restored.selectedBathOption,
      cafeteria: restored.cafeteria,
      garage: restored.garage,
      changingRoom: restored.changingRoom,
      seats: '',
      length: '',
      width: '',
      hasBall: restored.hasBall ?? false,
      ballPrice: 0,
      startTime: null,
      endTime: null,
      isSplitShift: false,
      breakTimes: const [],
      uploadedUrls: const [],
    );
    expect(payload['cafeteria'], isTrue);
    expect(payload['garage'], isFalse);
    expect(tester.takeException(), isNull);
  });
}
