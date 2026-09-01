import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enterprise Remote Feature Flag & Kill Switch Engine for VSP.
/// Allows instant disabling or enabling of platform capabilities (e.g. online payment, maintenance mode)
/// from the cloud without requiring a mobile app store update.
class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  final Map<String, dynamic> _flags = {
    'is_online_payment_enabled': true,
    'is_maintenance_mode': false,
    'is_championships_enabled': true,
    'is_matchups_enabled': true,
    'min_app_version': '1.0.0',
    'max_daily_bookings_per_user': 3,
  };

  bool _isFetched = false;

  /// Fetch remote feature flags from Supabase `app_settings` table
  Future<void> fetchRemoteFlags() async {
    try {
      final response = await Supabase.instance.client
          .from('app_settings')
          .select('key, value')
          .timeout(const Duration(seconds: 4));

      for (final row in response) {
        if (row['key'] != null && row['value'] != null) {
          final key = row['key'].toString();
          _flags[key] = row['value'];
        }
      }
      _isFetched = true;
      debugPrint('[FeatureFlagService] Remote flags synchronized: ${_flags.keys.length} flags loaded.');
    } catch (e) {
      debugPrint('[FeatureFlagService] Offline or remote fetch skipped, using safe fallbacks: $e');
    }
  }

  /// Check if a boolean feature is enabled (with offline-safe fallback)
  bool isEnabled(String flagKey, {bool defaultValue = true}) {
    if (_flags.containsKey(flagKey)) {
      final val = _flags[flagKey];
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      if (val is num) return val == 1;
    }
    return defaultValue;
  }

  /// Get integer threshold flag
  int getInt(String flagKey, {int defaultValue = 0}) {
    if (_flags.containsKey(flagKey)) {
      final val = _flags[flagKey];
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Get string config flag
  String getString(String flagKey, {String defaultValue = ''}) {
    if (_flags.containsKey(flagKey)) {
      return _flags[flagKey]?.toString() ?? defaultValue;
    }
    return defaultValue;
  }

  /// Online payment kill switch check
  bool get isOnlinePaymentEnabled => isEnabled('is_online_payment_enabled', defaultValue: true);

  /// Maintenance mode check
  bool get isMaintenanceMode => isEnabled('is_maintenance_mode', defaultValue: false);

  /// Status of sync
  bool get isFetched => _isFetched;
}
