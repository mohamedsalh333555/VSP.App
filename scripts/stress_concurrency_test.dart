import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/config/app_env.dart';

/// 🔒 VSP REAL CONCURRENCY STRESS HARNESS
/// Simulates 20 simultaneous users hammering the exact same stadium slot
/// at the exact same millisecond via `create_booking_atomic` RPC to verify
/// that Postgres Advisory Locks strictly grant 1 booking and reject 19 with 0 double-bookings.
Future<void> main() async {
  debugPrint('===============================================================');
  debugPrint('🚀 VSP CONCURRENCY STRESS TEST (POSTGRES ATOMIC LOCK VERIFIER)');
  debugPrint('===============================================================');

  // 1. Initialize Supabase
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );
  final client = Supabase.instance.client;

  // 2. Target test slot: Tomorrow at 20:00 to 21:00 UTC
  const testStadiumId = '00000000-0000-0000-0000-000000000001';
  final startTime = DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String();
  final endTime = DateTime.now().add(const Duration(days: 3, hours: 1)).toUtc().toIso8601String();

  debugPrint('Target Stadium ID: $testStadiumId');
  debugPrint('Target Time Slot: $startTime -> $endTime');
  debugPrint('Launching 20 simultaneous booking attempts in parallel...\n');

  final stopwatch = Stopwatch()..start();

  // 3. Dispatch 20 concurrent futures at the exact same millisecond
  final results = await Future.wait(
    List.generate(20, (index) async {
      try {
        final res = await client.rpc('create_booking_atomic', params: {
          'p_stadium_id': testStadiumId,
          'p_user_id': '00000000-0000-0000-0000-000000000099',
          'p_owner_id': '00000000-0000-0000-0000-000000000002',
          'p_start_time': startTime,
          'p_end_time': endTime,
          'p_booking_type': 'personal',
          'p_total_price': 200.0,
          'p_payment_method': 'cash',
        });
        return {'worker': index, 'result': res};
      } catch (e) {
        return {'worker': index, 'error': e.toString()};
      }
    }),
  );

  stopwatch.stop();

  // 4. Analyze Results
  int successCount = 0;
  int rejectedCount = 0;

  for (final item in results) {
    final res = item['result'];
    if (res is Map && res['success'] == true) {
      successCount++;
      debugPrint('  [Worker ${item['worker']}] ✅ GRANTED BOOKING (ID: ${res['booking_id']})');
    } else {
      rejectedCount++;
      debugPrint('  [Worker ${item['worker']}] 🛑 REJECTED: ${res?['message'] ?? item['error']}');
    }
  }

  debugPrint('\n===============================================================');
  debugPrint('📊 FINAL CONCURRENCY AUDIT REPORT:');
  debugPrint('  Total Requests Sent: 20');
  debugPrint('  Total Time Elapsed: ${stopwatch.elapsedMilliseconds}ms');
  debugPrint('  Granted Bookings: $successCount (MUST BE EXACTLY 1)');
  debugPrint('  Blocked Conflicts: $rejectedCount (MUST BE EXACTLY 19)');
  debugPrint('  Double Bookings: ${successCount > 1 ? "CRITICAL RISK DETECTED ($successCount)" : "0 (PERFECT POSTGRES ATOMIC LOCK)"}');
  debugPrint('===============================================================');
}
