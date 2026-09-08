import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/image_pick_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

enum StadiumImagePickType { multiple, single16x9 }

class StadiumWizardImageService {
  static final ImagePicker _imagePicker = ImagePicker();
  static final StorageService _storageService = StorageService();

  static Future<StadiumImagePickType?> showImageSourceModal(BuildContext context) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return showModalBottomSheet<StadiumImagePickType>(
      context: context,
      backgroundColor: VSPColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(VSPSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(
                isArabic ? 'إضافة صور للملعب' : 'Add Stadium Photos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Iconsax.gallery_copy, color: VSPColors.accent),
                title: Text(isArabic ? 'اختيار عدة صور من المعرض' : 'Pick multiple photos'),
                subtitle: Text(
                  isArabic ? 'رفع متسلسل تلقائي مع شريط تقدم' : 'Automatic sequential upload with progress',
                ),
                onTap: () => Navigator.pop(sheetCtx, StadiumImagePickType.multiple),
              ),
              ListTile(
                leading: const Icon(Iconsax.crop_copy, color: VSPColors.accent),
                title: Text(isArabic ? 'صورة واحدة مع ضبط الأبعاد (16:9)' : 'Single photo with 16:9 crop'),
                subtitle: Text(isArabic ? 'أفضل كصورة غلاف رئيسية' : 'Best as main cover photo'),
                onTap: () => Navigator.pop(sheetCtx, StadiumImagePickType.single16x9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<XFile?> pickSingleCroppedImage(BuildContext context) async {
    try {
      return await ImagePickService.pick(
        context,
        aspectRatio: CropAspectRatioPreset.ratio16x9,
      );
    } catch (e) {
      debugPrint('Error picking single cropped image: $e');
      return null;
    }
  }

  static Future<List<XFile>> pickMultipleImages() async {
    try {
      return await _imagePicker.pickMultiImage();
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return [];
    }
  }

  static Future<String?> uploadImageFile({
    required XFile xFile,
    required void Function(int progress) onProgress,
  }) async {
    final imageFile = File(xFile.path);
    Timer? progressTimer;

    try {
      int currentProgress = 10;
      progressTimer = Timer.periodic(const Duration(milliseconds: 150), (t) {
        if (currentProgress < 90) {
          currentProgress += 10;
          onProgress(currentProgress);
        } else {
          t.cancel();
        }
      });

      final url = await _storageService.uploadFile(
        file: xFile,
        bucket: 'stadium-images',
        path: 'stadiums/images/std_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      progressTimer.cancel();

      if (url == null || url.isEmpty) {
        return null;
      }

      // Cleanup cached file from local temp folder after upload
      try {
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (_) {}

      return url;
    } catch (e) {
      progressTimer?.cancel();
      debugPrint('Error uploading stadium image file: $e');
      return null;
    }
  }

  static Future<void> deleteUploadedImage(String url) async {
    try {
      await _storageService.deleteFile(url);
    } catch (e) {
      debugPrint('Error deleting uploaded image: $e');
    }
  }
}
