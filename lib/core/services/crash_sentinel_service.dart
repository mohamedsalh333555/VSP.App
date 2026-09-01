import 'package:flutter/foundation.dart';

/// Enterprise Crash & Error Sentinel for VSP.
/// Intercepts unhandled synchronous & asynchronous Flutter errors, formats diagnostics,
/// and prepares telemetry payloads for Sentry / Firebase Crashlytics ingestion.
class CrashSentinelService {
  static bool _initialized = false;
  static final List<Map<String, dynamic>> _inMemoryBreadcrumbs = [];

  /// Initialize global crash observers and error boundaries
  static void initialize({
    void Function(Object error, StackTrace stack)? onCrashReported,
  }) {
    if (_initialized) return;
    _initialized = true;

    // 1. Capture Flutter framework errors (Widget build errors, layout overflow, rendering)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _handleException(
        error: details.exception,
        stack: details.stack ?? StackTrace.current,
        context: details.context?.toString(),
        library: details.library,
        onCrashReported: onCrashReported,
      );
    };

    // 2. Capture asynchronous Dart errors outside Flutter's zone
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _handleException(
        error: error,
        stack: stack,
        context: 'PlatformDispatcher.onError (Async)',
        onCrashReported: onCrashReported,
      );
      return true; // Prevent app crashing abruptly
    };

    debugPrint('[CrashSentinel] Global Error Boundaries & Telemetry Initialized.');
  }

  /// Add a user action breadcrumb to trace user journey leading up to an error
  static void addBreadcrumb(String message, {String category = 'action'}) {
    final entry = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'category': category,
      'message': message,
    };
    _inMemoryBreadcrumbs.add(entry);
    if (_inMemoryBreadcrumbs.length > 50) {
      _inMemoryBreadcrumbs.removeAt(0);
    }
  }

  static void _handleException({
    required Object error,
    required StackTrace stack,
    String? context,
    String? library,
    void Function(Object error, StackTrace stack)? onCrashReported,
  }) {
    final report = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'error': error.toString(),
      'context': context ?? 'Unknown Context',
      'library': library ?? 'General',
      'recentBreadcrumbs': List.from(_inMemoryBreadcrumbs),
    };

    debugPrint('[CrashSentinel Exception Caught] $report');
    onCrashReported?.call(error, stack);
  }

  /// Get recent breadcrumbs for support tickets / debug logs
  static List<Map<String, dynamic>> get recentBreadcrumbs => List.unmodifiable(_inMemoryBreadcrumbs);
}
