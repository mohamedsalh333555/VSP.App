import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/add_stadium_step3_images.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_draft_service.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_media_coordinator.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_payload_builder.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('owner selects cover and the selected photo is saved first',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final images = <Map<String, dynamic>>[
      {'url': 'https://example.invalid/first.jpg'},
      {'url': 'https://example.invalid/cover.jpg'},
    ];
    var changes = 0;
    Widget screen() => MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AddStadiumStep3Images(
              images: images,
              isUploading: false,
              isSaving: false,
              onPickImage: () {},
              onDeleteImage: (_) {},
              onSetCover: (image) {
                StadiumWizardMediaCoordinator.setCoverImage(
                  image: image,
                  images: images,
                  stadiumId: null,
                  uid: 'owner-1',
                  onStateChanged: () => changes++,
                );
              },
              onSubmit: () {},
            ),
          ),
        );

    await tester.pumpWidget(screen());
    expect(find.text('Cover Photo'), findsOneWidget);
    await tester.tap(find.byTooltip('Set as cover'));
    await tester.pumpWidget(screen());
    expect(changes, 1);
    expect(images.first['url'], 'https://example.invalid/cover.jpg');

    final draft = await StadiumWizardDraftService.loadDraft('owner-1');
    expect(draft.images.first['url'], 'https://example.invalid/cover.jpg');
    final payload = StadiumWizardPayloadBuilder.buildUpdatePayload(
      name: 'Pitch',
      location: 'Aswan',
      governorate: 'Aswan',
      pricePerHour: 100,
      capacity: 5,
      requireDeposit: false,
      depositAmount: 0,
      uploadedUrls: images.map((entry) => entry['url'] as String).toList(),
      notes: '',
      features: const {},
      startTime: const TimeOfDay(hour: 16, minute: 0),
      endTime: const TimeOfDay(hour: 23, minute: 0),
      latitude: null,
      longitude: null,
    );
    expect(payload['imageUrl'], 'https://example.invalid/cover.jpg');
    expect(tester.takeException(), isNull);
  });
}
