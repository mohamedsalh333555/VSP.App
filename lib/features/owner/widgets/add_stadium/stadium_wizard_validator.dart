import 'package:flutter/material.dart';
import 'stadium_wizard_time_utils.dart';

/// Pure stateless validation logic for AddStadiumWizard steps.
class StadiumWizardValidator {
  const StadiumWizardValidator._();

  /// Validates Step 0 (Basic details and working hours).
  /// Returns an error message String if invalid, or `null` if valid.
  static String? validateStep0({
    required String location,
    required String name,
    required String stadiumPhone,
    required String? sportType,
    required String price,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required bool isSplitShift,
    required List<Map<String, TimeOfDay?>> breakTimes,
    required bool isArabic,
  }) {
    if (location.trim().isEmpty) {
      return isArabic
          ? 'يرجى تحديد موقع الملعب على الخريطة أولاً'
          : 'Please select stadium location on map first';
    }

    if (name.trim().isEmpty) {
      return isArabic
          ? 'يرجى إدخال اسم الملعب'
          : 'Please enter stadium name';
    }

    if (stadiumPhone.trim().isEmpty) {
      return isArabic
          ? 'يرجى إدخال رقم هاتف الملعب'
          : 'Please enter stadium phone number';
    }

    if (sportType == null || sportType.trim().isEmpty) {
      return isArabic
          ? 'يرجى اختيار نوع الرياضة'
          : 'Please select sport type';
    }

    if (price.trim().isEmpty) {
      return isArabic
          ? 'يرجى إدخال سعر حجز الملعب للساعة'
          : 'Please enter stadium hourly price';
    }

    if (startTime == null || endTime == null) {
      return isArabic
          ? 'يرجى تحديد مواعيد العمل (البداية والنهاية)'
          : 'Please select working hours (start and end)';
    }

    // ── Split-Shift Validation ──
    if (isSplitShift) {
      if (breakTimes.isEmpty) {
        return isArabic
            ? 'يرجى إضافة فترة راحة واحدة على الأقل عند تفعيل الراحة.'
            : 'Please add at least one break time.';
      }

      for (var i = 0; i < breakTimes.length; i++) {
        final bStart = breakTimes[i]['start'];
        final bEnd = breakTimes[i]['end'];
        if (bStart == null || bEnd == null) {
          return isArabic
              ? 'يرجى تحديد وقت البداية والنهاية لفترة الراحة ${i + 1}.'
              : 'Please set start and end times for Break ${i + 1}.';
        }

        int t(TimeOfDay time) => time.hour * 60 + time.minute;
        final start = t(startTime);
        final end = t(endTime);
        final bStartMin = t(bStart);
        final bEndMin = t(bEnd);

        int normEnd = (end <= start) ? end + (24 * 60) : end;
        int normBStart = (bStartMin < start && end <= start) ? bStartMin + (24 * 60) : bStartMin;
        int normBEnd = (bEndMin < start && end <= start) ? bEndMin + (24 * 60) : bEndMin;

        bool isBreakInHours = normBStart >= start && normBEnd <= normEnd && normBStart < normBEnd;

        if (!isBreakInHours) {
          return isArabic
              ? 'فترة الراحة ${i + 1} يجب أن تكون داخل مواعيد العمل الرسمية (${StadiumWizardTimeUtils.formatTime(startTime, '')} - ${StadiumWizardTimeUtils.formatTime(endTime, '')}).'
              : 'Break ${i + 1} must be within opening hours (${StadiumWizardTimeUtils.formatTime(startTime, '')} - ${StadiumWizardTimeUtils.formatTime(endTime, '')}).';
        }
      }
    }

    return null;
  }

  /// Validates Step 1 (Amenities, features, and deposits).
  /// Returns an error message String if invalid, or `null` if valid.
  static String? validateStep1({
    required String? selectedBathOption,
    required bool? cafeteria,
    required bool? hasBall,
    required String ballPriceText,
    required bool requireDeposit,
    required String depositText,
    required String priceText,
    required bool isArabic,
    required String selectFeaturesError,
    required String ballPriceMinError,
  }) {
    if (selectedBathOption == null || cafeteria == null) {
      return selectFeaturesError;
    }

    if (hasBall == true) {
      final ballPrice = double.tryParse(ballPriceText) ?? 0.0;
      if (ballPrice < 5.0) {
        return ballPriceMinError;
      }
    }

    if (requireDeposit) {
      final deposit = double.tryParse(depositText.trim()) ?? 0.0;
      final price = double.tryParse(priceText.trim()) ?? 0.0;
      if (deposit <= 0) {
        return isArabic
            ? 'يرجى إدخال مبلغ عربون صحيح.'
            : 'Please set a valid deposit amount.';
      }
      if (deposit > (price * 0.5)) {
        return isArabic
            ? 'مبلغ العربون لا يمكن أن يتجاوز 50% من سعر الساعة (${(price * 0.5).toStringAsFixed(0)} ج.م).'
            : 'Deposit amount cannot exceed 50% of the hourly price (${price * 0.5} EGP).';
      }
    }

    return null;
  }

  /// Validates Step 2 (Photos and upload status).
  /// Returns an error message String if invalid, or `null` if valid.
  static String? validateStep2({
    required List<Map<String, dynamic>> images,
    required String? stadiumId,
    required String uploadPhotoError,
  }) {
    if (images.isEmpty && stadiumId == null) {
      return uploadPhotoError;
    }
    if (images.any((img) => img['isUploading'] == true)) {
      return 'Please wait for all images to finish uploading.';
    }
    return null;
  }
}
