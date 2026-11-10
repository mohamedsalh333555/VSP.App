import 'package:flutter/material.dart';
import '../../../../core/providers/auth_provider.dart' as app_auth;
import '../../../../core/repositories/stadium_repository.dart';
import '../../../../core/repositories/user_repository.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../l10n/app_localizations.dart';
import 'stadium_wizard_draft_service.dart';
import 'stadium_wizard_payload_builder.dart';
import 'stadium_wizard_image_service.dart';

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
    required Set<String> removedExistingImageUrls,
    required double? latitude,
    required double? longitude,
    required String? uid,
  }) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (auth.userModel?.isBlocked == true) {
      VSPFeedback.showError(
        context,
        isArabic
            ? 'حسابك موقوف، ولا يمكنك حفظ بيانات الملعب أو إرسالها.'
            : 'Your account is blocked. You cannot save or submit stadium details.',
      );
      return false;
    }

    try {
      final uploadedUrls = images
          .map((img) => img['url'])
          .whereType<String>()
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final user = auth.currentUser;

      if (user == null) {
        VSPFeedback.showError(
          context,
          isArabic ? 'انتهت جلسة تسجيل الدخول. سجّل الدخول مرة أخرى.' : 'Authentication lost. Please login again.',
        );
        return false;
      }

      if (uid != null && uid.isNotEmpty && uid != user.uid) {
        VSPFeedback.showError(
          context,
          isArabic
              ? 'تغيّر الحساب أثناء إعداد الملعب. أعد فتح النموذج من الحساب الحالي.'
              : 'The account changed while this stadium was being prepared. Reopen the form from the current account.',
        );
        return false;
      }

      final pricePerHour = double.tryParse(priceText.trim());
      final capacity = int.tryParse(capacityText.trim());
      final depositAmount =
          requireDeposit ? double.tryParse(depositText.trim()) : 0.0;
      final ballPrice = hasBall ? double.tryParse(ballPriceText.trim()) : 0.0;
      final hasValidCoordinates =
          (latitude == null && longitude == null) ||
          (latitude != null &&
              longitude != null &&
              latitude.isFinite &&
              longitude.isFinite &&
              latitude >= -90 &&
              latitude <= 90 &&
              longitude >= -180 &&
              longitude <= 180);
      final hasValidCommercialValues =
          pricePerHour != null &&
          pricePerHour.isFinite &&
          pricePerHour >= 0 &&
          capacity != null &&
          capacity > 0 &&
          depositAmount != null &&
          depositAmount.isFinite &&
          depositAmount >= 0 &&
          (!requireDeposit || depositAmount <= pricePerHour * 0.5) &&
          ballPrice != null &&
          ballPrice.isFinite &&
          (!hasBall || ballPrice >= 5);

      if (!hasValidCommercialValues || !hasValidCoordinates) {
        VSPFeedback.showError(
          context,
          isArabic
              ? 'راجع السعر والسعة والعربون وسعر الكرة والموقع قبل الحفظ.'
              : 'Review the price, capacity, deposit, ball price, and location before saving.',
        );
        return false;
      }

      if (uploadedUrls.isEmpty) {
        VSPFeedback.showError(
          context,
          isArabic
              ? 'أضف صورة واحدة على الأقل للملعب قبل الإرسال.'
              : 'Add at least one stadium image before submitting.',
        );
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
        ballPrice: ballPrice!,
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
          pricePerHour: pricePerHour!,
          capacity: capacity!,
          requireDeposit: requireDeposit,
          depositAmount: depositAmount!,
          uploadedUrls: uploadedUrls,
          notes: notes,
          features: stadiumFeatures,
          startTime: startTime,
          endTime: endTime,
          latitude: latitude,
          longitude: longitude,
        );
        await databaseService.updateStadium(stadiumId, updatePayload);
        var cleanupFailed = false;
        for (final removedUrl in removedExistingImageUrls) {
          final deleted =
              await StadiumWizardImageService.deleteUploadedImage(removedUrl);
          cleanupFailed = cleanupFailed || !deleted;
        }
        if (cleanupFailed) {
          if (context.mounted) {
            VSPFeedback.showError(
              context,
              isArabic
                  ? 'تم حفظ بيانات الملعب، لكن تعذر حذف بعض الصور القديمة. اضغط حفظ مرة تانية لإعادة المحاولة.'
                  : 'Stadium details were saved, but some old photos could not be deleted. Save again to retry.',
            );
          }
          return false;
        }
        removedExistingImageUrls.clear();
      } else {
        final newId = await databaseService.createStadium(
          name: name.trim(),
          location: location.trim(),
          governorate: governorate,
          pricePerHour: pricePerHour!,
          seatsCapacity: capacity!,
          depositAmount: depositAmount!,
          needsDeposit: requireDeposit,
          imageUrl: uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
          images: uploadedUrls,
          ownerId: user.uid,
          lat: latitude,
          lng: longitude,
          notes: notes.trim().isEmpty
              ? (isArabic
                  ? 'نحرص على توفير بيئة احترافية. يرجى الحضور في الموعد المحدد والمحافظة على الملعب ومعداته. قد يؤدي التأخر إلى تقليل وقت اللعب.'
                  : 'We ensure a professional environment. Please arrive on time. Respect the facility and equipment. Late arrival may result in reduced playing time.')
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
        var profileSyncFailed = false;
        try {
          if (stadiumId == null) {
            await StadiumWizardDraftService.clearDraft(uid);
            await UserRepository().updateOnboardingConfirmed(user.uid, true);
            await auth.updateProfile({
              'hasStadium': true,
              'is_onboarding_confirmed': true,
            });
          }
          await auth.refreshProfile();
        } catch (syncError, stackTrace) {
          profileSyncFailed = true;
          debugPrint('Stadium was saved, but owner profile synchronization failed: $syncError');
          debugPrintStack(stackTrace: stackTrace);
        }

        if (!context.mounted) return true;
        final successMessage = stadiumId == null
            ? (isArabic ? 'تم حفظ بيانات الملعب وإرسالها للمراجعة.' : 'Stadium details were saved and submitted for review.')
            : (isArabic ? 'تم حفظ التعديلات وإرسالها للمراجعة.' : 'Changes were saved and submitted for review.');
        final syncWarning = isArabic
            ? 'تم حفظ الملعب، لكن تعذر تحديث بعض بيانات الحساب. أعد فتح التطبيق أو سجّل الدخول مرة أخرى.'
            : 'The stadium was saved, but some account details could not be refreshed. Reopen the app or sign in again.';
        if (profileSyncFailed) {
          VSPFeedback.showError(context, syncWarning);
        } else {
          VSPFeedback.showSuccess(context, successMessage);
        }
        Navigator.pop(context);
        return true;
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        final rawMsg = e.toString().replaceFirst('Exception: ', '').trim();
        final errorMsg = rawMsg.isNotEmpty && (rawMsg.contains('باقتك') || rawMsg.contains('الحد الأقصى'))
            ? rawMsg
            : AppLocalizations.of(context)!.stadiumSaveFailed;
        VSPFeedback.showError(context, errorMsg);
      }
      return false;
    }
  }
}
