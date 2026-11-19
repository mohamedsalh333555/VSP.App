import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vsp_application/core/services/image_pick_service.dart';

class RecordingPicker extends ImagePicker {
  bool? metadata;
  ImageSource? source;
  int? quality;
  XFile? result;
  List<XFile> multiple = [];

  @override
  Future<XFile?> pickImage({
    required ImageSource source, double? maxWidth, double? maxHeight,
    int? imageQuality, CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source; quality = imageQuality; metadata = requestFullMetadata;
    return result;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth, double? maxHeight, int? imageQuality, int? limit,
    bool requestFullMetadata = true,
  }) async {
    metadata = requestFullMetadata;
    return multiple;
  }
}

void main() {
  for (final source in [ImageSource.gallery, ImageSource.camera]) {
    test('$source selects only the requested image without full metadata', () async {
      final picker = RecordingPicker()..result = XFile('/chosen/image.jpg');
      final result = await ImagePickService.pickRaw(source: source, imageQuality: 75, picker: picker);
      expect(result, same(picker.result));
      expect(picker.metadata, isFalse);
      expect(picker.source, source); expect(picker.quality, 75);
    });
  }
  test('cancelled image selection remains cancelled', () async {
    expect(await ImagePickService.pickRaw(picker: RecordingPicker()), isNull);
  });
  test('multiple selected files remain available without full metadata', () async {
    final picker = RecordingPicker()..multiple = [XFile('/a.jpg'), XFile('/b.png')];
    expect(await ImagePickService.pickMultiple(picker: picker), same(picker.multiple));
    expect(picker.metadata, isFalse);
  });
}
