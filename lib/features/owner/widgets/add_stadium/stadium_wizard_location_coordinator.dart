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
    Future<LocationResult?> Function()? pickOnMap,
  }) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    LocationResult? result;
    if (pickOnMap != null) {
      result = await pickOnMap();
    } else {
      result = await AddStadiumLocationPickerSheet.show(
        context, initialLat: currentLat, initialLng: currentLng,
      );
    }

    if (result != null && _hasValidCoordinates(result)) {
      if (!isEditing) {
        await StadiumWizardDraftService.saveDouble(uid, 'lat', result.latitude);
        await StadiumWizardDraftService.saveDouble(uid, 'lng', result.longitude);
        await StadiumWizardDraftService.saveString(uid, 'location', result.address);
        if (result.governorate != null) {
          await StadiumWizardDraftService.saveString(uid, 'governorate', result.governorate!);
        }
      }
      if (context.mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم تحديد موقع الملعب بنجاح' : 'Stadium location selected successfully',
        );
      }
    }

    return result != null && _hasValidCoordinates(result) ? result : null;
  }

  /// Opens the manual address modal without map tiles and persists the coordinates & address.
  static Future<LocationResult?> pickManualLocation(
    BuildContext context, {
    required String? currentGov,
    required String? currentAddress,
    required String? uid,
    required bool isEditing,
    Future<LocationResult?> Function()? pickManually,
  }) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    LocationResult? result;
    if (pickManually != null) {
      result = await pickManually();
    } else {
      result = await AddStadiumLocationPickerSheet.showManualAddressDialog(
        context,
        initialGovernorate: currentGov,
        initialAddress: currentAddress,
      );
    }

    if (result != null && _hasValidCoordinates(result)) {
      if (!isEditing) {
        await StadiumWizardDraftService.saveDouble(uid, 'lat', result.latitude);
        await StadiumWizardDraftService.saveDouble(uid, 'lng', result.longitude);
        await StadiumWizardDraftService.saveString(uid, 'location', result.address);
        if (result.governorate != null) {
          await StadiumWizardDraftService.saveString(uid, 'governorate', result.governorate!);
        }
      }
      if (context.mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم حفظ عنوان الملعب بنجاح' : 'Stadium address saved successfully',
        );
      }
    }

    return result != null && _hasValidCoordinates(result) ? result : null;
  }

  static bool _hasValidCoordinates(LocationResult location) =>
      location.latitude.isFinite && location.longitude.isFinite &&
      location.latitude >= -90 && location.latitude <= 90 &&
      location.longitude >= -180 && location.longitude <= 180;
}
