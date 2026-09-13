import 'package:flutter/material.dart';
import 'stadium_wizard_time_utils.dart';

/// Pure stateless payload constructor for AddStadiumWizard create & update operations.
class StadiumWizardPayloadBuilder {
  const StadiumWizardPayloadBuilder._();

  /// Builds the nested `features` JSON map.
  static Map<String, dynamic> buildFeatures({
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
    required double ballPrice,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required bool isSplitShift,
    required List<Map<String, TimeOfDay?>> breakTimes,
    required List<String> uploadedUrls,
  }) {
    final validBreaks = isSplitShift
        ? breakTimes.where((bt) => bt['start'] != null && bt['end'] != null).toList()
        : <Map<String, TimeOfDay?>>[];
    final hasValidBreaks = isSplitShift && validBreaks.isNotEmpty;

    return {
      'stadiumPhone': stadiumPhone.trim(),
      'sportType': sportType,
      'floorType': floorType,
      'bathOption': bathOption,
      'cafeteria': cafeteria,
      'garage': garage,
      'changingRoom': changingRoom,
      'seats': seats.trim(),
      'length': length.trim(),
      'width': width.trim(),
      'hasBall': hasBall,
      'ballPrice': hasBall ? ballPrice : 0.0,
      'workingHours': {
        'start': StadiumWizardTimeUtils.formatTime(startTime, '16:00:00'),
        'end': StadiumWizardTimeUtils.formatTime(endTime, '23:00:00'),
      },
      'isSplitShift': hasValidBreaks,
      'breakTimes': hasValidBreaks
          ? validBreaks.map((bt) => {
                'start': StadiumWizardTimeUtils.formatTime(bt['start'], ''),
                'end': StadiumWizardTimeUtils.formatTime(bt['end'], ''),
              }).toList()
          : [],
      'breakTime': hasValidBreaks
          ? {
              'start': StadiumWizardTimeUtils.formatTime(validBreaks.first['start'], ''),
              'end': StadiumWizardTimeUtils.formatTime(validBreaks.first['end'], ''),
            }
          : null,
      'allImages': uploadedUrls,
    };
  }

  /// Builds the update payload map passed to `StadiumRepository.updateStadium`.
  static Map<String, dynamic> buildUpdatePayload({
    required String name,
    required String location,
    required String? governorate,
    required double pricePerHour,
    required int capacity,
    required bool requireDeposit,
    required double depositAmount,
    required List<String> uploadedUrls,
    required String notes,
    required Map<String, dynamic> features,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required double? latitude,
    required double? longitude,
  }) {
    return {
      'name': name.trim(),
      'location': location.trim(),
      'governorate': governorate,
      'pricePerHour': pricePerHour,
      'players_per_team': capacity,
      'total_field_capacity': capacity * 2,
      'deposit_amount': requireDeposit ? depositAmount : 0.0,
      'needs_deposit': requireDeposit,
      'imageUrl': uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
      'images': uploadedUrls,
      'notes': notes.trim(),
      'features': features,
      'opening_time': StadiumWizardTimeUtils.formatTime(startTime, '16:00:00'),
      'closing_time': StadiumWizardTimeUtils.formatTime(endTime, '03:00:00'),
      'lat': latitude,
      'lng': longitude,
    };
  }
}
