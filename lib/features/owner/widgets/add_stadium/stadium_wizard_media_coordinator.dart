import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/vsp_feedback.dart';
import 'stadium_wizard_draft_service.dart';
import 'stadium_wizard_image_service.dart';

/// Coordinator managing image picking, progressive upload, and removal in the stadium wizard.
class StadiumWizardMediaCoordinator {
  const StadiumWizardMediaCoordinator._();

  /// Prompts user for photo source and processes single or multiple image uploads.
  static Future<void> pickAndUpload({
    required BuildContext context,
    required List<Map<String, dynamic>> images,
    required String? stadiumId,
    required String? uid,
    required VoidCallback onStateChanged,
  }) async {
    final pickType = await StadiumWizardImageService.showImageSourceModal(context);
    if (pickType == null || !context.mounted) return;

    if (pickType == StadiumImagePickType.single16x9) {
      final xFile = await StadiumWizardImageService.pickSingleCroppedImage(context);
      if (xFile != null && context.mounted) {
        await uploadFile(
          context: context,
          xFile: xFile,
          images: images,
          stadiumId: stadiumId,
          uid: uid,
          onStateChanged: onStateChanged,
        );
      }
    } else if (pickType == StadiumImagePickType.multiple) {
      final files = await StadiumWizardImageService.pickMultipleImages();
      if (files.isEmpty || !context.mounted) return;

      final total = files.length;
      for (int i = 0; i < total; i++) {
        if (!context.mounted) break;
        await uploadFile(
          context: context,
          xFile: files[i],
          images: images,
          stadiumId: stadiumId,
          uid: uid,
          currentIndex: i + 1,
          totalCount: total,
          onStateChanged: onStateChanged,
        );
      }
    }
  }

  /// Uploads single file with progress reporting and updates the images collection.
  static Future<void> uploadFile({
    required BuildContext context,
    required XFile xFile,
    required List<Map<String, dynamic>> images,
    required String? stadiumId,
    required String? uid,
    required VoidCallback onStateChanged,
    int? currentIndex,
    int? totalCount,
  }) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final progressLabel = (currentIndex != null && totalCount != null && totalCount > 1)
        ? (isArabic ? "جارٍ رفع الصورة $currentIndex من $totalCount" : "Uploading photo $currentIndex of $totalCount")
        : null;

    final imageEntry = <String, dynamic>{
      'file': null,
      'url': null,
      'isUploading': true,
      'progress': 10,
      'statusLabel': progressLabel,
    };

    images.add(imageEntry);
    onStateChanged();

    final ownerId = uid?.trim();
    if (ownerId == null || ownerId.isEmpty) {
      images.remove(imageEntry);
      onStateChanged();
      VSPFeedback.showError(
        context,
        isArabic ? 'تعذر تحديد حساب مالك الملعب. سجل الدخول وحاول مرة أخرى.' : 'Owner account could not be verified. Please sign in again.',
      );
      return;
    }

    final url = await StadiumWizardImageService.uploadImageFile(
      xFile: xFile,
      ownerId: ownerId,
      onProgress: (progress) {
        imageEntry['progress'] = progress;
        onStateChanged();
      },
    );

    if (!context.mounted) return;

    if (url == null) {
      images.remove(imageEntry);
      onStateChanged();
      VSPFeedback.showError(context, isArabic ? 'فشل رفع الصورة، يرجى المحاولة ثانية.' : 'Failed to upload photo.');
      return;
    }

    imageEntry['url'] = url;
    imageEntry['progress'] = 100;
    imageEntry['isUploading'] = false;
    onStateChanged();

    if (stadiumId == null) {
      StadiumWizardDraftService.saveImages(uid, images);
    }
  }

  /// Deletes uploaded image from storage and updates state and draft.
  static Future<void> deleteImage({
    required Map<String, dynamic> image,
    required List<Map<String, dynamic>> images,
    required String? stadiumId,
    required String? uid,
    required VoidCallback onStateChanged,
  }) async {
    if (image['url'] != null) {
      await StadiumWizardImageService.deleteUploadedImage(image['url']!);
    }
    images.remove(image);
    onStateChanged();
    if (stadiumId == null) {
      StadiumWizardDraftService.saveImages(uid, images);
    }
  }
}
