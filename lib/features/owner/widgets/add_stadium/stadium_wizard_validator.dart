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
    final hourlyPrice = double.tryParse(price.trim());
    if (hourlyPrice == null || !hourlyPrice.isFinite || hourlyPrice < 0) {
      return isArabic
          ? 'يرجى إدخال سعر صحيح للساعة لا يقل عن صفر.'
          : 'Enter a valid hourly price of zero or more.';
    }

    if (startTime == null || endTime == null) {
      return isArabic
          ? 'يرجى تحديد مواعيد العمل (البداية والنهاية)'
          : 'Please select working hours (start and end)';
    }

    // A split shift means at least one complete closure interval. Never
    // ignore a half-configured break and accidentally expose it as bookable.
    if (!StadiumWizardTimeUtils.isSplitShiftValid(
      startTime: startTime,
      endTime: endTime,
      isSplitShift: isSplitShift,
      breakTimes: breakTimes,
    )) {
      return isArabic
          ? 'فترة الراحة 1 يجب أن تكون داخل مواعيد العمل الرسمية، مكتملة، وغير متداخلة.'
          : 'Break 1 must be complete, inside operating hours, and must not overlap another break.';
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
      final ballPrice = double.tryParse(ballPriceText.trim());
      if (ballPrice == null || !ballPrice.isFinite || ballPrice < 5.0) {
        return ballPriceMinError;
      }
    }

    if (requireDeposit) {
      final deposit = double.tryParse(depositText.trim());
      final price = double.tryParse(priceText.trim());
      if (deposit == null || !deposit.isFinite || deposit <= 0) {
        return isArabic
            ? 'يرجى إدخال مبلغ عربون صحيح أكبر من الصفر عند تفعيل خيار العربون.'
            : 'Please enter a valid deposit amount greater than zero when deposit is required.';
      }
      if (price != null && price.isFinite && price > 0 && deposit > (price * 0.5)) {
        return isArabic
            ? 'مبلغ العربون لا يمكن أن يتجاوز 50% من سعر الساعة (${(price * 0.5).toStringAsFixed(0)} ج.م).'
            : 'Deposit amount cannot exceed 50% of the hourly price (${(price * 0.5).toStringAsFixed(0)} EGP).';
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
    required bool isArabic,
  }) {
    if (images.isEmpty) {
      return uploadPhotoError;
    }
    if (images.any((img) => img['isUploading'] == true)) {
      return isArabic
          ? 'يرجى الانتظار حتى يكتمل رفع جميع الصور.'
          : 'Please wait for all images to finish uploading.';
    }
    return null;
  }
}
