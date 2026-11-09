import 'package:flutter/material.dart';
import '../../../../core/repositories/stadium_repository.dart';
import 'stadium_wizard_time_utils.dart';

/// Data transfer object representing all populated fields loaded from an existing stadium snapshot.
class StadiumLoadedData {
  final String ownerId;
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
    required this.ownerId,
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

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  static double _asDouble(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '') ?? fallback;
  }

  static bool _asBool(dynamic value, [bool fallback = false]) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return fallback;
  }

  /// Loads stadium record by ID and parses working hours, break times, features, and images.
  static Future<StadiumLoadedData?> load(
    String stadiumId, {
    required StadiumRepository repository,
  }) async {
    try {
      final data = await repository.getStadiumSnapshot(stadiumId);
      if (data == null) return null;

      final depositVal =
          _asDouble(data['deposit_amount'] ?? data['depositAmount']);
      final reqDeposit = _asBool(
        data['needs_deposit'] ?? data['needsDeposit'],
        depositVal > 0,
      );

      final features = _asMap(data['features']);
      final workingHours = _asMap(features['workingHours']);

      TimeOfDay? start;
      TimeOfDay? end;
      if (workingHours.isNotEmpty) {
        start = StadiumWizardTimeUtils.parseTime(workingHours['start']);
        end = StadiumWizardTimeUtils.parseTime(workingHours['end']);
      }

      final List<Map<String, TimeOfDay?>> breaks = [];
      final rawBreaks = features['breakTimes'];
      if (rawBreaks is List) {
        for (final item in rawBreaks) {
          final parsed = _asMap(item);
          if (parsed.isEmpty) continue;
          final breakStart =
              StadiumWizardTimeUtils.parseTime(parsed['start']?.toString());
          final breakEnd =
              StadiumWizardTimeUtils.parseTime(parsed['end']?.toString());
          if (breakStart != null && breakEnd != null) {
            breaks.add({'start': breakStart, 'end': breakEnd});
          }
        }
      }
      if (breaks.isEmpty) {
        final breakTime = _asMap(features['breakTime']);
        if (breakTime.isNotEmpty) {
          final breakStart =
              StadiumWizardTimeUtils.parseTime(breakTime['start']?.toString());
          final breakEnd =
              StadiumWizardTimeUtils.parseTime(breakTime['end']?.toString());
          if (breakStart != null && breakEnd != null) {
            breaks.add({'start': breakStart, 'end': breakEnd});
          }
        }
      }

      final allImages = <String>[];
      if (data['images'] is List) {
        for (var img in (data['images'] as List)) {
          final url = img?.toString().trim() ?? '';
          if (url.isNotEmpty && url.toLowerCase() != 'null' && !allImages.contains(url)) {
            allImages.add(url);
          }
        }
      }
      if (features['allImages'] is List) {
        for (var img in (features['allImages'] as List)) {
          final str = img?.toString().trim() ?? '';
          if (str.isNotEmpty && str.toLowerCase() != 'null' && !allImages.contains(str)) {
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
        parsedImages.add({'file': null, 'url': url, 'isUploading': false, 'isNewUpload': false});
      }

      return StadiumLoadedData(
        ownerId: (data['owner_id'] ?? data['ownerId'] ?? '').toString().trim(),
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
        isSplitShift: _asBool(features['isSplitShift']) && breaks.isNotEmpty,
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
