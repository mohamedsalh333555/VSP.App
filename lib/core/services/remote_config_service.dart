import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enterprise Realtime Remote Config & Feature Flag Engine.
/// Features:
/// 1. Instant Zero-Delay Offline Cache via SharedPreferences
/// 2. Live Instant Updates via Supabase Realtime Stream Subscription
/// 3. Robust Type-Safe Parsing Resilient against schema variations
class RemoteConfigService extends ChangeNotifier {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;

  // Configuration Fields & Defaults
  bool _isMaintenanceMode = false;
  String _minAppVersion = '';
  String _forceUpdateUrl = '';
  bool _is1v1RegistrationOpen = false;
  String _vsp1v1Link = '';
  double _stadiumPriceDefault = 0.0;
  bool _copilotEnabled = false;

  final Map<String, dynamic> _features = {};

  // Getters
  bool get isMaintenanceMode => _isMaintenanceMode;
  String get minAppVersion => _minAppVersion;
  String get forceUpdateUrl => _forceUpdateUrl;
  bool get is1v1RegistrationOpen => _is1v1RegistrationOpen;
  String get vsp1v1Link => _vsp1v1Link;
  double get stadiumPriceDefault => _stadiumPriceDefault;
  bool get copilotEnabled => _copilotEnabled;
  Map<String, dynamic> get features => Map.unmodifiable(_features);

  bool isFeatureEnabled(String key, {bool defaultValue = false}) {
    if (_features.containsKey(key)) {
      final val = _features[key];
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      if (val is num) return val == 1;
    }
    return defaultValue;
  }

  /// Initialize from Supabase first. Cached values are never treated as current truth.
  Future<void> initialize() async {
    await _fetchLatestConfig();
    _subscribeToRealtimeUpdates();
  }

  Future<void> _fetchLatestConfig() async {
    final response = await _supabase
        .from('app_config')
        .select()
        .maybeSingle();

    if (response == null) {
      throw StateError('VSP app configuration is unavailable in Supabase.');
    }

    _parseConfig(response);
    notifyListeners();
  }

  void _subscribeToRealtimeUpdates() {
    _streamSubscription?.cancel();
    try {
      _streamSubscription = _supabase
          .from('app_config')
          .stream(primaryKey: ['id'])
          .listen((data) {
        if (data.isNotEmpty) {
          final latestRow = data.first;
          _parseConfig(latestRow);
          notifyListeners();
          debugPrint('[RemoteConfigService] Realtime config updated instantly from Supabase.');
        }
      }, onError: (error) {
        debugPrint('[RemoteConfigService] Realtime stream error: $error');
      });
    } catch (e) {
      debugPrint('[RemoteConfigService] Could not subscribe to realtime stream: $e');
    }
  }

  /// Robust, Type-Safe Parsing (Resilient against format variations)
  void _parseConfig(Map<String, dynamic> data) {
    _isMaintenanceMode = _parseBool(data['is_maintenance'] ?? data['isMaintenanceMode'], _isMaintenanceMode);
    _minAppVersion = _parseString(data['min_version'] ?? data['minAppVersion'], _minAppVersion);
    _forceUpdateUrl = _parseString(data['force_update_url'] ?? data['forceUpdateUrl'], _forceUpdateUrl);
    _is1v1RegistrationOpen = _parseBool(data['vsp_1v1_is_open'] ?? data['vsp1v1IsOpen'], _is1v1RegistrationOpen);
    _vsp1v1Link = _parseString(data['vsp_1v1_link'] ?? data['vsp1v1Link'], _vsp1v1Link);
    _stadiumPriceDefault = _parseDouble(data['stadium_price_default'] ?? data['stadiumPriceDefault'], _stadiumPriceDefault);
    _copilotEnabled = _parseBool(data['copilot_enabled'] ?? data['copilotEnabled'], _copilotEnabled);

    // Dynamic features map support
    final rawFeatures = data['features'];
    if (rawFeatures != null && rawFeatures is Map) {
      rawFeatures.forEach((key, val) {
        _features[key.toString()] = val;
      });
    }
    _features['1v1_enabled'] = _is1v1RegistrationOpen;
    _features['copilot_enabled'] = _copilotEnabled;
  }

  static bool _parseBool(dynamic val, bool fallback) {
    if (val == null) return fallback;
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final s = val.trim().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return fallback;
  }

  static double _parseDouble(dynamic val, double fallback) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  static String _parseString(dynamic val, String fallback) {
    if (val == null) return fallback;
    return val.toString().trim();
  }

  Future<void> fetchConfig() async {
    await _fetchLatestConfig();
  }

  Future<bool> shouldForceUpdate() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      return _isVersionLower(currentVersion, _minAppVersion);
    } catch (e) {
      debugPrint('[RemoteConfigService] Error checking force update: $e');
      return false;
    }
  }

  bool _isVersionLower(String current, String min) {
    try {
      List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> minParts = min.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int m = i < minParts.length ? minParts[i] : 0;
        if (c < m) return true;
        if (c > m) return false;
      }
    } catch (_) {}
    return false;
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
