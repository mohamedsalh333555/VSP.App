import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StadiumDraftData {
  final int currentStep;
  final String name;
  final String location;
  final double? latitude;
  final double? longitude;
  final String? governorate;
  final String price;
  final String capacity;
  final String phone;
  final String notes;
  final String length;
  final String width;
  final String seats;
  final String ballPrice;
  final String deposit;
  final String? sportType;
  final String? floorType;
  final String? bathOption;
  final bool? cafeteria;
  final bool? garage;
  final bool? changingRoom;
  final bool? hasBall;
  final bool requireDeposit;
  final bool isSplitShift;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final List<Map<String, TimeOfDay?>> breakTimes;
  final List<Map<String, dynamic>> images;

  const StadiumDraftData({
    this.currentStep = 0,
    this.name = '',
    this.location = '',
    this.latitude,
    this.longitude,
    this.governorate,
    this.price = '',
    this.capacity = '',
    this.phone = '',
    this.notes = '',
    this.length = '',
    this.width = '',
    this.seats = '',
    this.ballPrice = '',
    this.deposit = '',
    this.sportType,
    this.floorType,
    this.bathOption,
    this.cafeteria,
    this.garage,
    this.changingRoom,
    this.hasBall,
    this.requireDeposit = false,
    this.isSplitShift = false,
    this.startTime,
    this.endTime,
    this.breakTimes = const [],
    this.images = const [],
  });
}

class StadiumWizardDraftService {
  static String getPrefix(String? uid) {
    return (uid != null && uid.isNotEmpty) ? 'vsp_draft_stadium_${uid}_' : 'temp_stadium_';
  }

  static Future<void> saveString(String? uid, String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${getPrefix(uid)}$key', value);
  }

  static Future<void> saveBool(String? uid, String key, bool? value) async {
    final prefs = await SharedPreferences.getInstance();
    final fullKey = '${getPrefix(uid)}$key';
    if (value == null) {
      await prefs.remove(fullKey);
    } else {
      await prefs.setBool(fullKey, value);
    }
  }

  static Future<void> saveDouble(String? uid, String key, double? value) async {
    final prefs = await SharedPreferences.getInstance();
    final fullKey = '${getPrefix(uid)}$key';
    if (value == null) {
      await prefs.remove(fullKey);
    } else {
      await prefs.setDouble(fullKey, value);
    }
  }

  static Future<void> saveStep(String? uid, int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${getPrefix(uid)}current_step', step);
  }

  static Future<void> saveWorkingHours(
    String? uid, {
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    List<Map<String, TimeOfDay?>> breakTimes = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = getPrefix(uid);

    if (startTime != null) {
      await prefs.setString('${prefix}start_time', '${startTime.hour}:${startTime.minute}');
    }
    if (endTime != null) {
      await prefs.setString('${prefix}end_time', '${endTime.hour}:${endTime.minute}');
    }
    if (breakTimes.isNotEmpty) {
      final list = breakTimes.map((bt) => {
        'start': bt['start'] != null ? '${bt['start']!.hour}:${bt['start']!.minute}' : null,
        'end': bt['end'] != null ? '${bt['end']!.hour}:${bt['end']!.minute}' : null,
      }).toList();
      await prefs.setString('${prefix}break_times', json.encode(list));
    }
  }

  static Future<void> saveImages(String? uid, List<Map<String, dynamic>> images) async {
    final prefs = await SharedPreferences.getInstance();
    final savedList = images
        .where((img) => img['url'] != null && img['url'].toString().isNotEmpty)
        .map((img) => {'url': img['url'], 'progress': 100, 'isUploading': false})
        .toList();
    await prefs.setString('${getPrefix(uid)}images', json.encode(savedList));
  }

  static Future<StadiumDraftData> loadDraft(String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = getPrefix(uid);

      String getStr(String key) => prefs.getString('$prefix$key') ?? prefs.getString('temp_stadium_$key') ?? '';
      bool? getBool(String key) => prefs.getBool('$prefix$key') ?? prefs.getBool('temp_stadium_$key');
      double? getDouble(String key) => prefs.getDouble('$prefix$key') ?? prefs.getDouble('temp_stadium_$key');
      int? getInt(String key) => prefs.getInt('${prefix}current_step') ?? prefs.getInt('temp_stadium_current_step');

      TimeOfDay? parseTime(String? str) {
        if (str == null || str.isEmpty) return null;
        final parts = str.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
        }
        return null;
      }

      final startTime = parseTime(getStr('start_time'));
      final endTime = parseTime(getStr('end_time'));

      final breakTimes = <Map<String, TimeOfDay?>>[];
      final breakTimesStr = getStr('break_times');
      if (breakTimesStr.isNotEmpty) {
        try {
          final List decoded = json.decode(breakTimesStr);
          for (final item in decoded) {
            if (item is Map) {
              breakTimes.add({
                'start': parseTime(item['start']?.toString()),
                'end': parseTime(item['end']?.toString()),
              });
            }
          }
        } catch (_) {}
      }

      final images = <Map<String, dynamic>>[];
      final imagesStr = getStr('images');
      if (imagesStr.isNotEmpty) {
        try {
          final List decoded = json.decode(imagesStr);
          for (final item in decoded) {
            if (item is Map && item['url'] != null) {
              images.add({
                'file': null,
                'url': item['url'],
                'progress': 100,
                'isUploading': false,
              });
            }
          }
        } catch (_) {}
      }

      final savedGov = getStr('governorate');
      final savedSport = getStr('sport_type');
      final savedFloor = getStr('floor_type');
      final savedBath = getStr('bath_option');

      return StadiumDraftData(
        currentStep: getInt('current_step') ?? 0,
        name: getStr('name'),
        location: getStr('location'),
        latitude: getDouble('lat'),
        longitude: getDouble('lng'),
        governorate: savedGov.isNotEmpty ? savedGov : null,
        price: getStr('price'),
        capacity: getStr('capacity'),
        phone: getStr('phone'),
        notes: getStr('notes'),
        length: getStr('length'),
        width: getStr('width'),
        seats: getStr('seats'),
        ballPrice: getStr('ball_price'),
        deposit: getStr('deposit'),
        sportType: savedSport.isNotEmpty ? savedSport : null,
        floorType: savedFloor.isNotEmpty ? savedFloor : null,
        bathOption: savedBath.isNotEmpty ? savedBath : null,
        cafeteria: getBool('cafeteria'),
        garage: getBool('garage'),
        changingRoom: getBool('changing_room'),
        hasBall: getBool('has_ball'),
        requireDeposit: getBool('require_deposit') ?? false,
        isSplitShift: getBool('is_split_shift') ?? false,
        startTime: startTime,
        endTime: endTime,
        breakTimes: breakTimes,
        images: images,
      );
    } catch (_) {
      return const StadiumDraftData();
    }
  }

  static Future<void> clearDraft(String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = getPrefix(uid);
      final suffixes = [
        'current_step', 'name', 'location', 'lat', 'lng', 'governorate',
        'price', 'capacity', 'phone', 'notes', 'length', 'width', 'seats',
        'ball_price', 'deposit', 'sport_type', 'floor_type', 'bath_option',
        'cafeteria', 'garage', 'changing_room', 'has_ball', 'require_deposit',
        'is_split_shift', 'start_time', 'end_time', 'break_times', 'images',
      ];
      for (final s in suffixes) {
        await prefs.remove('$prefix$s');
        await prefs.remove('temp_stadium_$s');
      }
    } catch (_) {}
  }
}
