import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote feature flags. Supabase is authoritative; failure never enables a feature.
class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  final Map<String, dynamic> _flags = {};
  bool _isFetched = false;

  /// Reads the single authoritative app_settings row.
  /// The table is column-based, not key/value based.
  Future<void> fetchRemoteFlags() async {
    try {
      final settingsRow = await Supabase.instance.client
          .from('app_settings')
          .select()
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      final configRow = await Supabase.instance.client
          .from('app_config')
          .select()
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (settingsRow == null || configRow == null) {
        throw StateError('VSP runtime configuration is unavailable in Supabase.');
      }

      _flags
        ..clear()
        ..addAll({
          'is_online_payment_enabled': settingsRow['online_payment_enabled'],
          'is_cash_booking_enabled': settingsRow['cash_booking_enabled'],
          'is_maintenance_mode': configRow['is_maintenance'],
          'is_1v1_registration_open': configRow['vsp_1v1_is_open'],
        });

      _isFetched = true;
      debugPrint('[FeatureFlagService] Remote flags synchronized from Supabase.');
    } catch (e) {
      _flags.clear();
      _isFetched = false;
      debugPrint('[FeatureFlagService] Remote flags unavailable; features remain fail-closed: $e');
    }
  }

  bool isEnabled(String flagKey, {bool defaultValue = false}) {
    final val = _flags[flagKey];
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    if (val is num) return val == 1;
    return false;
  }

  int getInt(String flagKey, {int defaultValue = 0}) {
    final val = _flags[flagKey];
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  String getString(String flagKey, {String defaultValue = ''}) {
    final val = _flags[flagKey];
    return val?.toString() ?? '';
  }

  bool get isOnlinePaymentEnabled =>
      isEnabled('is_online_payment_enabled', defaultValue: false);

  bool get isMaintenanceMode => isEnabled('is_maintenance_mode', defaultValue: false);

  bool get isFetched => _isFetched;
}
