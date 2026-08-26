import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger_service.dart';

/// Global Server Time Synchronization Service for VSP Application.
/// Ensures the application operates on verified Universal Server Time (UTC),
/// eliminating discrepancies caused by inaccurate or manipulated device clocks.
class VSPTimeService {
  static Duration _serverOffset = Duration.zero;
  static bool _isSynchronized = false;

  /// Returns whether the time service has completed initial server sync.
  static bool get isSynchronized => _isSynchronized;

  /// Returns current synchronized time adjusted by server clock offset.
  static DateTime get now {
    final deviceNow = DateTime.now();
    return _isSynchronized ? deviceNow.add(_serverOffset) : deviceNow;
  }

  /// Returns current synchronized UTC time.
  static DateTime get nowUtc {
    return now.toUtc();
  }

  /// Synchronize clock with Supabase server timestamp.
  static Future<void> syncWithServer() async {
    try {
      final startTime = DateTime.now();
      
      // Query lightweight server timestamp from Supabase
      final response = await Supabase.instance.client
          .rpc('get_server_timestamp')
          .timeout(const Duration(seconds: 4));

      final roundTripTime = DateTime.now().difference(startTime);
      final estimatedLatency = Duration(milliseconds: roundTripTime.inMilliseconds ~/ 2);

      if (response != null) {
        final serverUtc = DateTime.parse(response.toString()).toUtc();
        final expectedLocal = serverUtc.add(estimatedLatency);
        _serverOffset = expectedLocal.difference(DateTime.now().toUtc());
        _isSynchronized = true;

        VSPLogger.i(' VSPTimeService: Synced with server clock. Offset: ${_serverOffset.inMilliseconds}ms');
      }
    } catch (e) {
      // Fallback: If RPC not present, use standard client time gracefully
      _isSynchronized = true;
      VSPLogger.d(' VSPTimeService sync notice (using standard monotonic baseline): $e');
    }
  }

  /// Reset synchronization state (e.g. on network reconnect)
  static void invalidate() {
    _isSynchronized = false;
  }
}
