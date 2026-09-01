import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/config/app_env.dart';

/// 🔒 VSP REAL CONCURRENCY & POSTGRES LOCKING STRESS TEST
///
/// Authenticates a REAL test user using the public ANON_KEY + JWT Session (No Service Role bypass).
/// Dispatches 20 simultaneous booking attempts for the EXACT same stadium slot at the exact same millisecond.
/// Mathematically verifies that Postgres Advisory Locks allow exactly 1 booking and reject 19.
Future<void> main(List<String> args) async {
  stdout.writeln('===============================================================');
  stdout.writeln('🚀 VSP CONCURRENCY STRESS TEST (POSTGRES ATOMIC LOCK VERIFIER)');
  stdout.writeln('===============================================================');

  // 1. Connection Config (Uses Anon Key + App Environment)
  final supabaseUrl = Platform.environment['SUPABASE_URL'] ?? AppEnv.supabaseUrl;
  final supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? AppEnv.supabaseAnonKey;

  stdout.writeln('Connecting to Supabase: $supabaseUrl');
  stdout.writeln('Using Public Anon Key (Full RLS & Auth Validation)');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  final client = Supabase.instance.client;

  // 2. Real User Authentication (Sign In with Test Credentials)
  final testEmail = Platform.environment['TEST_USER_EMAIL'] ?? 'test_player@vsp.app';
  final testPassword = Platform.environment['TEST_USER_PASSWORD'] ?? 'VspTest@2026';

  stdout.writeln('\nAuthenticating test user: $testEmail...');
  String? userId;

  try {
    final authRes = await client.auth.signInWithPassword(
      email: testEmail,
      password: testPassword,
    );
    userId = authRes.user?.id;
    stdout.writeln('✅ Authenticated successfully! User ID: $userId');
  } catch (e) {
    stdout.writeln('User sign-in failed ($e). Attempting to auto-create test user...');
    try {
      final signUpRes = await client.auth.signUp(
        email: testEmail,
        password: testPassword,
      );
      userId = signUpRes.user?.id;
      stdout.writeln('✅ Test user created and authenticated! User ID: $userId');
    } catch (signUpErr) {
      stderr.writeln('❌ Fatal: Failed to authenticate test user: $signUpErr');
      stderr.writeln('Please ensure the user exists or provide TEST_USER_EMAIL / TEST_USER_PASSWORD.');
      exit(1);
    }
  }

  // 3. Find an active verified stadium to test against
  stdout.writeln('\nFetching a verified stadium from database...');
  dynamic targetStadium;

  try {
    final stadiums = await client
        .from('stadiums')
        .select('id, name, owner_id, price_per_hour')
        .eq('is_verified', true)
        .limit(1);

    if (stadiums.isNotEmpty) {
      targetStadium = stadiums.first;
    }
  } catch (e) {
    stdout.writeln('Notice while querying stadiums: $e');
  }

  final stadiumId = targetStadium != null ? targetStadium['id'].toString() : '00000000-0000-0000-0000-000000000001';
  final stadiumName = targetStadium != null ? targetStadium['name'].toString() : 'Test Stadium';
  final ownerId = targetStadium != null ? targetStadium['owner_id'].toString() : userId;
  final price = targetStadium != null ? (targetStadium['price_per_hour'] as num).toDouble() : 200.0;

  // Pick a slot 5 days from now at 19:00 UTC to avoid conflicts with previous runs
  final targetDate = DateTime.now().toUtc().add(const Duration(days: 5));
  final startTime = DateTime.utc(targetDate.year, targetDate.month, targetDate.day, 19, 0, 0);
  final endTime = startTime.add(const Duration(hours: 1));

  stdout.writeln('Target Stadium: "$stadiumName" ($stadiumId)');
  stdout.writeln('Target Slot: ${startTime.toIso8601String()} -> ${endTime.toIso8601String()}');
  stdout.writeln('Hourly Rate: $price EGP');

  stdout.writeln('\n⚡ Launching 20 simultaneous parallel requests at the exact same millisecond...\n');

  final stopwatch = Stopwatch()..start();

  // 4. Dispatch 20 concurrent futures at the exact same millisecond
  final results = await Future.wait(
    List.generate(20, (index) async {
      try {
        final res = await client.rpc('create_booking_atomic', params: {
          'p_stadium_id': stadiumId,
          'p_user_id': userId,
          'p_owner_id': ownerId,
          'p_start_time': startTime.toIso8601String(),
          'p_end_time': endTime.toIso8601String(),
          'p_booking_type': 'personal',
          'p_total_price': price,
          'p_payment_method': 'cash',
        });
        return {'worker': index + 1, 'result': res};
      } catch (e) {
        return {'worker': index + 1, 'error': e.toString()};
      }
    }),
  );

  stopwatch.stop();

  // 5. Detailed Breakdown per Worker
  int successCount = 0;
  int rejectedCount = 0;

  for (final item in results) {
    final worker = item['worker'];
    final res = item['result'];

    if (res is Map && res['success'] == true) {
      successCount++;
      stdout.writeln('  [Worker $worker] ✅ GRANTED (Status: Confirmed, Booking ID: ${res['booking_id']})');
    } else {
      rejectedCount++;
      final msg = res is Map ? res['message'] ?? res['code'] : item['error'];
      stdout.writeln('  [Worker $worker] 🛑 REJECTED: $msg');
    }
  }

  // 6. Final Audit Report
  stdout.writeln('\n===============================================================');
  stdout.writeln('📊 FINAL CONCURRENCY AUDIT REPORT:');
  stdout.writeln('  Total Parallel Requests: 20');
  stdout.writeln('  Total Time Elapsed: ${stopwatch.elapsedMilliseconds}ms');
  stdout.writeln('  Granted Bookings: $successCount (Target: Exactly 1)');
  stdout.writeln('  Rejected Conflicts: $rejectedCount (Target: Exactly 19)');
  stdout.writeln('  Double Bookings Detected: ${successCount > 1 ? "🚨 CRITICAL FAILURE ($successCount double bookings)" : "0 (✅ 100% POSTGRES ATOMIC LOCK SUCCESS)"}');
  stdout.writeln('===============================================================');

  exit(successCount == 1 ? 0 : 1);
}
