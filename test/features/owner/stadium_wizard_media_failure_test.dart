import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
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
    });
  }
}
