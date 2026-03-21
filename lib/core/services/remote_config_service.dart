import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  bool _isMaintenanceMode = false;
  String _minAppVersion = '1.0.0';
  String _forceUpdateUrl = '';

  bool get isMaintenanceMode => _isMaintenanceMode;
  String get minAppVersion => _minAppVersion;
  String get forceUpdateUrl => _forceUpdateUrl;

  Future<void> initialize() async {
    try {
      final snapshot = await _firestore.collection('config').doc('app_config').get();
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _isMaintenanceMode = data['isMaintenanceMode'] ?? false;
        _minAppVersion = data['minAppVersion'] ?? '1.0.0';
        _forceUpdateUrl = data['forceUpdateUrl'] ?? '';
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
