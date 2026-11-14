import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_draft_service.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_media_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final throwsFailure in [false, true]) {
    testWidgets('failed owner image upload removes placeholder ($throwsFailure)',
        (tester) async {
      final images = <Map<String, dynamic>>[];
      var changes = 0;
      String? uploadedForOwner;
      var sawUploadingPlaceholder = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                await StadiumWizardMediaCoordinator.uploadFile(
                  context: context,
                  xFile: XFile.fromData(Uint8List.fromList([1, 2, 3]),
                      name: 'stadium.jpg', mimeType: 'image/jpeg'),
                  images: images,
                  stadiumId: 'existing-stadium',
                  uid: 'owner-1',
                  onStateChanged: () => changes++,
                  uploadImage: (file, owner, onProgress) async {
                    uploadedForOwner = owner;
                    sawUploadingPlaceholder = images.single['isUploading'] == true;
                    if (throwsFailure) throw StateError('storage disconnected');
                    return null;
                  },
                );
              },
              child: const Text('Upload'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('Upload'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(images, isEmpty);
      expect(changes, 2);
      expect(uploadedForOwner, 'owner-1');
      expect(sawUploadingPlaceholder, isTrue);
      expect(find.text('Failed to upload photo.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('uploaded image can be removed and draft stays in sync',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (ctx) {
        context = ctx;
        return const Text('Owner gallery');
      })),
    ));
    final images = <Map<String, dynamic>>[];
    var changes = 0;
    await StadiumWizardMediaCoordinator.uploadFile(
      context: context,
      xFile: XFile.fromData(Uint8List.fromList([1, 2, 3]),
          name: 'stadium.jpg', mimeType: 'image/jpeg'),
      images: images,
      stadiumId: null,
      uid: 'owner-1',
      onStateChanged: () => changes++,
      uploadImage: (file, owner, progress) async {
        progress(50);
        return 'https://example.invalid/owner-1/stadium.jpg';
      },
    );
    expect(images.single['url'], 'https://example.invalid/owner-1/stadium.jpg');
    expect(images.single['progress'], 100);
    expect(changes, greaterThanOrEqualTo(3));
    await tester.pump();
    expect((await StadiumWizardDraftService.loadDraft('owner-1')).images, hasLength(1));

    String? deletedUrl;
    await StadiumWizardMediaCoordinator.deleteImage(
      image: images.single,
      images: images,
      removedExistingImageUrls: <String>{},
      stadiumId: null,
      uid: 'owner-1',
      onStateChanged: () => changes++,
      deleteUploaded: (url) async {
        deletedUrl = url;
        return true;
      },
    );
    expect(deletedUrl, 'https://example.invalid/owner-1/stadium.jpg');
    expect(images, isEmpty);
    await tester.pump();
    expect((await StadiumWizardDraftService.loadDraft('owner-1')).images, isEmpty);

    final existing = <String, dynamic>{'url': 'https://example.invalid/old.jpg'};
    images.add(existing);
    final pendingDeletion = <String>{};
    await StadiumWizardMediaCoordinator.deleteImage(
      image: existing,
      images: images,
      removedExistingImageUrls: pendingDeletion,
      stadiumId: 'stadium-1',
      uid: 'owner-1',
      onStateChanged: () => changes++,
      deleteUploaded: (_) => throw StateError('persisted image deleted early'),
    );
    expect(images, isEmpty);
    expect(pendingDeletion, {'https://example.invalid/old.jpg'});
    expect(tester.takeException(), isNull);
  });
}
