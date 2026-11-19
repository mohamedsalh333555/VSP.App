import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_image_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  var fileNumber = 0;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('vsp-image-validation-');
    fileNumber = 0;
  });
  tearDown(() async => temp.delete(recursive: true));

  Future<XFile> file(List<int> bytes, String name, String? mime) async {
    final onDisk = File('${temp.path}/${fileNumber++}-$name');
    await onDisk.writeAsBytes(bytes);
    return XFile(onDisk.path, mimeType: mime);
  }

  test('stadium image validator accepts supported matching signatures', () async {
    expect(await StadiumWizardImageService.isSupportedImage(await file(
      [0xff, 0xd8, 0xff, ...List.filled(9, 0)], 'pitch.jpg', 'image/jpeg',
    )), isTrue);
    expect(await StadiumWizardImageService.isSupportedImage(await file(
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0],
      'pitch.png', 'image/png',
    )), isTrue);
    expect(await StadiumWizardImageService.isSupportedImage(await file(
      [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50],
      'pitch.webp', 'image/webp',
    )), isTrue);
  });

  test('stadium image validator rejects spoofed type and excessive size', () async {
    final bogus = List<int>.filled(12, 0);
    expect(await StadiumWizardImageService.isSupportedImage(await file(
      bogus, 'pitch.jpg', 'image/jpeg',
    )), isFalse);
    expect(await StadiumWizardImageService.isSupportedImage(await file(
      [0xff, 0xd8, 0xff, ...List.filled(9, 0)], 'pitch.png', 'image/jpeg',
    )), isFalse);
    expect(await StadiumWizardImageService.isSupportedImage(await file(
      bogus, 'pitch.exe', 'image/jpeg',
    )), isFalse);
    expect(await StadiumWizardImageService.isSupportedImage(await file(
      [], 'pitch.jpg', 'image/jpeg',
    )), isFalse);
    final oversized = Uint8List(10 * 1024 * 1024 + 1);
    oversized.setRange(0, 3, [0xff, 0xd8, 0xff]);
    expect(await StadiumWizardImageService.isSupportedImage(
      await file(oversized, 'pitch.jpg', 'image/jpeg'),
    ), isFalse);
  });
}
