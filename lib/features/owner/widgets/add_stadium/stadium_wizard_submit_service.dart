import 'package:flutter/material.dart';
import '../../../../core/providers/auth_provider.dart' as app_auth;
import '../../../../core/repositories/stadium_repository.dart';
import '../../../../core/repositories/user_repository.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../l10n/app_localizations.dart';
import 'stadium_wizard_draft_service.dart';
import 'stadium_wizard_payload_builder.dart';

/// Service executing create or update operations for the stadium wizard.
class StadiumWizardSubmitService {
  const StadiumWizardSubmitService._();

  /// Submits the wizard form to create or update the pitch record.
  static Future<bool> submit({
    required BuildContext context,
    required app_auth.AuthProvider auth,
    required StadiumRepository databaseService,
    required String? stadiumId,
    required String name,
    required String location,
    required String? governorate,
    required String priceText,
    required String capacityText,
    required String depositText,
    required bool requireDeposit,
    required String notes,
    required String stadiumPhone,
    required String? sportType,
    required String? floorType,
    required String? bathOption,
    required bool? cafeteria,
    required bool? garage,
    required bool? changingRoom,
    required String seats,
    required String length,
    required String width,
    required bool hasBall,
    required String ballPriceText,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required bool isSplitShift,
    required List<Map<String, TimeOfDay?>> breakTimes,
    required List<Map<String, dynamic>> images,
    required double? latitude,
    required double? longitude,
    required String? uid,
  }) async {
    if (auth.userModel?.isBlocked == true) {
      VSPFeedback.showError(context, "Your account is blocked. You cannot save or submit stadium details.");
      return false;
    }

    try {
      final uploadedUrls = images
          .where((img) => img['url'] != null)
          .map((img) => img['url'] as String)
          .toList();
      final user = auth.firebaseUser;

      if (user == null) {
        VSPFeedback.showError(context, "Authentication lost. Please login again.");
        return false;
      }

      final stadiumFeatures = StadiumWizardPayloadBuilder.buildFeatures(
        stadiumPhone: stadiumPhone,
        sportType: sportType,
        floorType: floorType,
        bathOption: bathOption,
        cafeteria: cafeteria,
        garage: garage,
        changingRoom: changingRoom,
        seats: seats,
        length: length,
        width: width,
        hasBall: hasBall,
        ballPrice: double.tryParse(ballPriceText) ?? 0.0,
        startTime: startTime,
        endTime: endTime,
        isSplitShift: isSplitShift,
        breakTimes: breakTimes,
        uploadedUrls: uploadedUrls,
      );

      if (stadiumId != null) {
        final updatePayload = StadiumWizardPayloadBuilder.buildUpdatePayload(
          name: name,
          location: location,
          governorate: governorate,
          pricePerHour: double.tryParse(priceText.trim()) ?? 0.0,
          capacity: int.tryParse(capacityText.trim()) ?? 5,
          requireDeposit: requireDeposit,
          depositAmount: double.tryParse(depositText.trim()) ?? 0.0,
          uploadedUrls: uploadedUrls,
          notes: notes,
          features: stadiumFeatures,
          startTime: startTime,
          endTime: endTime,
          latitude: latitude,
          longitude: longitude,
        );
        await databaseService.updateStadium(stadiumId, updatePayload);
      } else {
        final newId = await databaseService.createStadium(
          name: name.trim(),
          location: location.trim(),
          governorate: governorate,
          pricePerHour: double.tryParse(priceText.trim()) ?? 0.0,
          seatsCapacity: int.tryParse(capacityText.trim()) ?? 5,
          depositAmount: requireDeposit ? (double.tryParse(depositText.trim()) ?? 0.0) : 0.0,
          needsDeposit: requireDeposit,
          imageUrl: uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
          images: uploadedUrls,
          ownerId: user.uid,
          lat: latitude,
          lng: longitude,
          notes: notes.trim().isEmpty
              ? "We ensure a professional environment. Please arrive on time. Respect the facility and equipment. Late arrival may result in reduced playing time."
              : notes.trim(),
          features: stadiumFeatures,
        );

        if (newId == null) {
          if (!context.mounted) return false;
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          VSPFeedback.showError(
            context,
            isArabic
                ? 'فشل إنشاء الملعب. يرجى مراجعة البيانات المدخلة وصلاحيات الحساب.'
                : 'Failed to create stadium. Please check your data or permissions.',
          );
          return false;
        }
      }

      if (context.mounted) {
        if (stadiumId == null) {
          await StadiumWizardDraftService.clearDraft(uid);
          await UserRepository().updateOnboardingConfirmed(user.uid, true);
          await auth.updateProfile({
            'hasStadium': true,
            'is_onboarding_confirmed': true,
          });
        }
        await auth.refreshProfile();

        if (!context.mounted) return true;
        final l10n = AppLocalizations.of(context)!;
        VSPFeedback.showSuccess(context, l10n.stadiumSubmitSuccess);
        Navigator.pop(context);
        return true;
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        VSPFeedback.showError(context, AppLocalizations.of(context)!.stadiumSaveFailed);
      }
      return false;
    }
  }
}
