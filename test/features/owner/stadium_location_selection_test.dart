import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_location_geocoder.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_draft_service.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_location_coordinator.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_payload_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('map choice persists coordinates and address for stadium payload',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (ctx) {
        context = ctx;
        return const Text('Location');
      })),
    ));
    const picked = LocationResult(
      latitude: 24.0889,
      longitude: 32.8998,
      address: 'Aswan city center',
      governorate: 'Aswan',
    );
    final result = await StadiumWizardLocationCoordinator.pickLocation(
      context,
      currentLat: null,
      currentLng: null,
      uid: 'owner-1',
      isEditing: false,
      pickOnMap: () async => picked,
    );
    expect(result?.address, picked.address);
    final draft = await StadiumWizardDraftService.loadDraft('owner-1');
    expect(draft.latitude, picked.latitude);
    expect(draft.longitude, picked.longitude);
    expect(draft.location, picked.address);
    expect(draft.governorate, picked.governorate);

    final payload = StadiumWizardPayloadBuilder.buildUpdatePayload(
      name: 'Aswan Pitch',
      location: draft.location,
      governorate: draft.governorate,
      pricePerHour: 100,
      capacity: 5,
      requireDeposit: false,
      depositAmount: 0,
      uploadedUrls: const [],
      notes: '',
      features: const {},
      startTime: null,
      endTime: null,
      latitude: draft.latitude,
      longitude: draft.longitude,
    );
    expect(payload['lat'], picked.latitude);
    expect(payload['lng'], picked.longitude);
    expect(payload['location'], picked.address);

    final invalid = await StadiumWizardLocationCoordinator.pickManualLocation(
      context,
      currentGov: 'Aswan',
      currentAddress: draft.location,
      uid: 'owner-1',
      isEditing: false,
      pickManually: () async => const LocationResult(
        latitude: double.nan,
        longitude: 32.8998,
        address: 'Invalid',
        governorate: 'Aswan',
      ),
    );
    expect(invalid, isNull);
    expect((await StadiumWizardDraftService.loadDraft('owner-1')).location, picked.address);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
