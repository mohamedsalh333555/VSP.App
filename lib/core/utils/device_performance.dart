import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

enum DeviceTier { low, medium, high }

/// Determines device capability tier at startup to selectively enable heavy shaders (like Glass Blur).
class DevicePerformance {
  static DeviceTier _tier = DeviceTier.medium;

  static DeviceTier get tier => _tier;

  static Future<void> init() async {
    if (kIsWeb) {
      _tier = DeviceTier.high;
      return;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        final isLowRam = androidInfo.isLowRamDevice;
        if (sdkInt < 26 || isLowRam) {
          _tier = DeviceTier.low;
        } else if (sdkInt >= 31) {
          _tier = DeviceTier.high;
        } else {
          _tier = DeviceTier.medium;
        }
      } else if (Platform.isIOS) {
        _tier = DeviceTier.high;
      } else {
        _tier = DeviceTier.high;
      }
    } catch (_) {
      _tier = DeviceTier.medium;
    }
  }

  @visibleForTesting
  static void setTierForTesting(DeviceTier tier) {
    _tier = tier;
  }
}
