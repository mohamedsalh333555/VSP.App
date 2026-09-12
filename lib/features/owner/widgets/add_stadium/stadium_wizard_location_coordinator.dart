import 'package:flutter/material.dart';
import '../../../../core/utils/vsp_feedback.dart';
import 'add_stadium_location_picker_sheet.dart';
import 'stadium_wizard_draft_service.dart';

/// Coordinates location picker bottom sheet display, draft saving, and feedback toast.
class StadiumWizardLocationCoordinator {
  const StadiumWizardLocationCoordinator._();

  /// Opens the location picker modal and persists the picked coordinates and address.
  static Future<LocationResult?> pickLocation(
    BuildContext context, {
    required double? currentLat,
    required double? currentLng,
    required String? uid,
    required bool isEditing,
  }) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final result = await AddStadiumLocationPickerSheet.show(
      context,
      initialLat: currentLat,
      initialLng: currentLng,
    );

    if (result != null) {
      if (!isEditing) {
        StadiumWizardDraftService.saveDouble(uid, 'lat', result.latitude);
        StadiumWizardDraftService.saveDouble(uid, 'lng', result.longitude);
        StadiumWizardDraftService.saveString(uid, 'location', result.address);
        if (result.governorate != null) {
          StadiumWizardDraftService.saveString(uid, 'governorate', result.governorate!);
        }
      }
      if (context.mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم تحديد موقع الملعب بنجاح' : 'Stadium location selected successfully',
        );
      }
    }

    return result;
  }

  /// Opens the manual address modal without map tiles and persists the coordinates & address.
  static Future<LocationResult?> pickManualLocation(
    BuildContext context, {
    required String? currentGov,
    required String? currentAddress,
    required String? uid,
    required bool isEditing,
  }) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final result = await AddStadiumLocationPickerSheet.showManualAddressDialog(
      context,
      initialGovernorate: currentGov,
      initialAddress: currentAddress,
    );

    if (result != null) {
      if (!isEditing) {
        StadiumWizardDraftService.saveDouble(uid, 'lat', result.latitude);
        StadiumWizardDraftService.saveDouble(uid, 'lng', result.longitude);
        StadiumWizardDraftService.saveString(uid, 'location', result.address);
        if (result.governorate != null) {
          StadiumWizardDraftService.saveString(uid, 'governorate', result.governorate!);
        }
      }
      if (context.mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم حفظ عنوان الملعب بنجاح' : 'Stadium address saved successfully',
        );
      }
    }

    return result;
  }
}
