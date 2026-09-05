import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'logger_service.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  static ConnectivityService get instance => _instance;

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityService._internal() {
    _init();
  }

  void _init() {
    // Initial check
    checkConnectivity().then((online) {
      isOnlineNotifier.value = online;
    }).catchError((e) {
      VSPLogger.w('Initial connectivity check error: $e');
    });

    // Listen to changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final online = _isOnline(results);
        if (isOnlineNotifier.value != online) {
          isOnlineNotifier.value = online;
          VSPLogger.i('Network connectivity changed: ${online ? "ONLINE" : "OFFLINE"}');
        }
      },
      onError: (e) {
        VSPLogger.w('Connectivity stream error: $e');
      },
    );
  }

  bool _isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged.map(_isOnline);

  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final online = _isOnline(results);
      isOnlineNotifier.value = online;
      return online;
    } catch (e) {
      VSPLogger.w('Failed to check connectivity: $e');
      return true; // Default to assuming online if check fails
    }
  }

  Future<bool> get isConnected => checkConnectivity();

  bool get isCurrentOnline => isOnlineNotifier.value;

  void dispose() {
    _subscription?.cancel();
    isOnlineNotifier.dispose();
  }
}
