import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

/// A centralised service that handles picking an image from the gallery
/// (or camera) and immediately opening an in-app crop/resize UI.
///
/// Usage:
/// ```dart
/// final XFile? file = await ImagePickService.pick(
///   context,
///   aspectRatio: CropAspectRatioPreset.square,
/// );
/// if (file != null) { /* upload */ }
/// ```
export 'package:image_cropper/image_cropper.dart' show CropAspectRatioPreset;

class ImagePickService {
  static final _picker = ImagePicker();

  /// Opens the gallery or camera, then shows the cropper UI.
  /// Returns an [XFile] containing the cropped image, or null if cancelled.
  static Future<XFile?> pick(
    BuildContext context, {
    CropAspectRatioPreset aspectRatio = CropAspectRatioPreset.square,
    ImageSource source = ImageSource.gallery,
  }) async {
    // 1. Pick raw image
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null) return null;

    final isFree = aspectRatio == CropAspectRatioPreset.original;
    final isSquare = aspectRatio == CropAspectRatioPreset.square;

    // 2. Open cropper — aspect ratio presets go inside each platform UiSettings
    final ratios = _ratios(aspectRatio);

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '',
          toolbarColor: const Color(0xFF0D0D0D),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF5FE3A1),
          backgroundColor: const Color(0xFF0D0D0D),
          dimmedLayerColor: Colors.black87,
          cropFrameColor: const Color(0xFF5FE3A1),
          cropGridColor: Colors.white24,
          cropStyle: isSquare ? CropStyle.circle : CropStyle.rectangle,
          showCropGrid: true,
          hideBottomControls: false,
          initAspectRatio: ratios.first,
          lockAspectRatio: !isFree,
          aspectRatioPresets: ratios,
        ),
        IOSUiSettings(
          title: '',
          doneButtonTitle: 'تم',
          cancelButtonTitle: 'إلغاء',
          aspectRatioLockEnabled: !isFree,
          aspectRatioPickerButtonHidden: !isFree,
          cropStyle: isSquare ? CropStyle.circle : CropStyle.rectangle,
          aspectRatioPresets: ratios,
        ),
      ],
    );

    if (cropped == null) return null;
    return XFile(cropped.path);
  }

  static List<CropAspectRatioPreset> _ratios(CropAspectRatioPreset preset) {
    switch (preset) {
      case CropAspectRatioPreset.square:
        return [CropAspectRatioPreset.square];
      case CropAspectRatioPreset.ratio16x9:
        return [CropAspectRatioPreset.ratio16x9];
      case CropAspectRatioPreset.original:
        // Free crop – give user multiple common options
        return [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9,
        ];
      default:
        return [preset];
    }
  }
}
