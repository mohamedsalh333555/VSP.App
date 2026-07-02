import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final _supabase = Supabase.instance.client;

  bool _isMaintenanceMode = false;
  String _minAppVersion = '1.0.0';
  String _forceUpdateUrl = '';

  bool get isMaintenanceMode => _isMaintenanceMode;
  String get minAppVersion => _minAppVersion;
  String get forceUpdateUrl => _forceUpdateUrl;

  Future<void> initialize() async {
    try {
      final response = await _supabase
          .from('app_config')
          .select()
          .maybeSingle();
      if (response != null) {
        _isMaintenanceMode = response['is_maintenance'] ?? response['isMaintenanceMode'] ?? false;
        _minAppVersion = response['min_version'] ?? response['minAppVersion'] ?? '1.0.0';
        _forceUpdateUrl = response['force_update_url'] ?? response['forceUpdateUrl'] ?? '';
      }
    } catch (e) {
      debugPrint('Error initializing RemoteConfigService: $e');
    }
  }

  Future<bool> shouldForceUpdate() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      return _isVersionLower(currentVersion, _minAppVersion);
    } catch (e) {
      debugPrint('Error checking force update: $e');
      return false;
    }
  }

  bool _isVersionLower(String current, String min) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> minParts = min.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
       int c = i < currentParts.length ? currentParts[i] : 0;
       int m = i < minParts.length ? minParts[i] : 0;
       if (c < m) return true;
       if (c > m) return false;
    }
    return false;
  }
}
