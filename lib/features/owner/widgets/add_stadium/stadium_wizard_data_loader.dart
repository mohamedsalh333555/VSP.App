import 'package:flutter/material.dart';
import '../../../../core/repositories/stadium_repository.dart';
import 'stadium_wizard_time_utils.dart';

/// Data transfer object representing all populated fields loaded from an existing stadium snapshot.
class StadiumLoadedData {
  final String name;
  final String location;
  final String price;
  final String capacity;
  final String deposit;
  final bool requireDeposit;
  final String phone;
  final String? floorType;
  final String? sportType;
  final String? bathOption;
  final bool? cafeteria;
  final bool? garage;
  final bool? changingRoom;
  final String seats;
  final String length;
  final String width;
  final bool hasBall;
  final String ballPrice;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool isSplitShift;
  final List<Map<String, TimeOfDay?>> breakTimes;
  final List<Map<String, dynamic>> images;
  final String notes;

  const StadiumLoadedData({
    required this.name,
    required this.location,
    required this.price,
    required this.capacity,
    required this.deposit,
    required this.requireDeposit,
    required this.phone,
    required this.floorType,
    required this.sportType,
    required this.bathOption,
    required this.cafeteria,
    required this.garage,
    required this.changingRoom,
    required this.seats,
    required this.length,
    required this.width,
    required this.hasBall,
    required this.ballPrice,
    required this.startTime,
    required this.endTime,
    required this.isSplitShift,
    required this.breakTimes,
    required this.images,
    required this.notes,
  });
}

/// Helper for fetching and parsing stadium details for edit mode in the wizard.
class StadiumWizardDataLoader {
  const StadiumWizardDataLoader._();

  /// Loads stadium record by ID and parses working hours, break times, features, and images.
  static Future<StadiumLoadedData?> load(
    String stadiumId, {
    required StadiumRepository repository,
  }) async {
    try {
      final data = await repository.getStadiumSnapshot(stadiumId);
      if (data == null) return null;

      final depositVal = data['deposit_amount'] ?? data['depositAmount'] ?? 0.0;
      final bool reqDeposit = data['needs_deposit'] ?? data['needsDeposit'] ?? (depositVal > 0.0);

      final features = data['features'] as Map<String, dynamic>? ?? {};
      final workingHours = features['workingHours'] as Map<String, dynamic>?;

      TimeOfDay? start;
      TimeOfDay? end;
      if (workingHours != null) {
        start = StadiumWizardTimeUtils.parseTime(workingHours['start']);
        end = StadiumWizardTimeUtils.parseTime(workingHours['end']);
      }

      final List<Map<String, TimeOfDay?>> breaks = [];
      if (features['breakTimes'] != null) {
        final list = features['breakTimes'] as List;
        for (var item in list) {
          if (item is Map) {
            breaks.add({
              'start': StadiumWizardTimeUtils.parseTime(item['start']?.toString()),
              'end': StadiumWizardTimeUtils.parseTime(item['end']?.toString()),
            });
          }
        }
      }
      if (breaks.isEmpty && features['breakTime'] != null) {
        final breakTime = features['breakTime'] as Map<String, dynamic>;
        breaks.add({
          'start': StadiumWizardTimeUtils.parseTime(breakTime['start']?.toString()),
          'end': StadiumWizardTimeUtils.parseTime(breakTime['end']?.toString()),
        });
      }

      final allImages = <String>[];
      if (data['images'] is List) {
        for (var img in (data['images'] as List)) {
          if (img != null && img.toString().isNotEmpty) {
            allImages.add(img.toString());
          }
        }
      }
      if (features['allImages'] is List) {
        for (var img in (features['allImages'] as List)) {
          final str = img.toString();
          if (str.isNotEmpty && !allImages.contains(str)) {
            allImages.add(str);
          }
        }
      }
      if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
        final str = data['imageUrl'].toString();
        if (!allImages.contains(str)) {
          allImages.insert(0, str);
        }
      }
      if (data['image_url'] != null && data['image_url'].toString().isNotEmpty) {
        final str = data['image_url'].toString();
        if (!allImages.contains(str)) {
          allImages.insert(0, str);
        }
      }

      final List<Map<String, dynamic>> parsedImages = [];
      for (var url in allImages) {
        parsedImages.add({'file': null, 'url': url, 'isUploading': false});
      }

      return StadiumLoadedData(
        name: data['name'] ?? '',
        location: data['location'] ?? '',
        price: (data['price_per_hour'] ?? data['pricePerHour'] ?? 0).toString(),
        capacity: (data['players_per_team'] ?? data['playersPerTeam'] ?? 5).toString(),
        deposit: depositVal == 0.0 ? '' : depositVal.toString(),
        requireDeposit: reqDeposit,
        phone: features['stadiumPhone']?.toString() ?? '',
        floorType: features['floorType'],
        sportType: features['sportType'],
        bathOption: features['bathOption'],
        cafeteria: features['cafeteria'],
        garage: features['garage'],
        changingRoom: features['changingRoom'],
        seats: features['seats'] ?? '',
        length: features['length'] ?? '',
        width: features['width'] ?? '',
        hasBall: features['hasBall'] ?? false,
        ballPrice: (features['ballPrice'] ?? 0).toString(),
        startTime: start,
        endTime: end,
        isSplitShift: features['isSplitShift'] ?? false,
        breakTimes: breaks,
        images: parsedImages,
        notes: data['notes'] ?? '',
      );
    } catch (e) {
      debugPrint('Error loading stadium data: $e');
      return null;
    }
  }
}
