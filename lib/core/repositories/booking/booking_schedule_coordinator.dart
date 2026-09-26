import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../services/logger_service.dart';

/// Coordinates booking rescheduling, manual booking updates, emergency closures, and locking mechanisms.
class BookingScheduleCoordinator {
  final SupabaseClient? _client;

  BookingScheduleCoordinator({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Updates manual booking information (deposit, phone, customer name, notes).
  Future<bool> updateManualBooking({
    required Booking? booking,
    required String bookingId,
    required String name,
    required String phone,
    required String notes,
    required bool isDepositPaid,
    required double depositPaid,
    required String paymentStatus,
  }) async {
    try {
      final result = await _supabase.rpc('owner_update_manual_booking_atomic', params: {
        'p_booking_id': bookingId,
        'p_end_time': (booking?.endTime ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
        'p_customer_name': name,
        'p_customer_phone': phone,
        'p_notes': notes,
        'p_current_players': booking?.currentPlayers ?? 1,
        'p_collected_amount': depositPaid,
      });
      if (result is Map && result['success'] == false) throw Exception(result['error'] ?? 'فشل تحديث الحجز');
      return true;
    } catch (e) {
      VSPLogger.e('Error updating manual booking: $e', e);
      rethrow;
    }
  }

  Future<bool> requestReschedule({
    required String bookingId,
    required DateTime newStartTime,
    required DateTime newEndTime,
  }) async {
    final result = await _supabase.rpc('request_booking_reschedule_atomic', params: {
      'p_booking_id': bookingId,
      'p_new_start': newStartTime.toUtc().toIso8601String(),
      'p_new_end': newEndTime.toUtc().toIso8601String(),
    });
    if (result is Map && result['success'] == false) throw Exception(result['error'] ?? 'فشل طلب تغيير الموعد');
    return true;
  }

  Future<bool> respondToReschedule({
    required Booking? booking,
    required String bookingId,
    required bool accept,
  }) async {
    if (booking == null) return false;
    final result = await _supabase.rpc('respond_booking_reschedule_atomic', params: {
      'p_booking_id': bookingId,
      'p_accept': accept,
    });
    if (result is Map && result['success'] == false) {
      if (result['error'] == 'CONFLICT_AUTO_CANCELLED') return false;
      throw Exception(result['error'] ?? 'فشل التعامل مع تغيير الموعد');
    }
    return true;
  }

  /// Requests emergency closure for pitch via server RPC.
  Future<Map<String, dynamic>> requestEmergencyClosure({
    required String stadiumId,
    required String ownerId,
    required String reason,
    required int durationHours,
  }) async {
    try {
      final rpcResult = await _supabase.rpc('request_emergency_stadium_closure', params: {
        'p_stadium_id': stadiumId,
        'p_owner_id': ownerId,
        'p_reason': reason,
        'p_duration_hours': durationHours,
      });

      if (rpcResult is Map) {
        return Map<String, dynamic>.from(rpcResult);
      }
      return {'success': true};
    } catch (e) {
      VSPLogger.e('Error requesting emergency closure via RPC', e);
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Cancels stale pending bookings for user and stadium older than 10 minutes.
  Future<void> cleanupStalePendingBookings({
    required String userId,
    required String stadiumId,
  }) async {
    try {

      await _supabase.rpc('cleanup_stale_pending_bookings_atomic', params: {
        'p_user_id': userId,
        'p_stadium_id': stadiumId,
      });
      debugPrint('Stale pending bookings transitioned to expired/cancelled safely.');
    } catch (e) {
      debugPrint('Error cleaning up stale bookings: $e');
    }
  }

  /// Simulates test payment webhook during development.
  Future<void> simulateTestPaymentWebhook(String bookingId) async {
    if (!kDebugMode) return;
    try {
      await _supabase.rpc('process_paymob_webhook', params: {
        'p_booking_id': bookingId,
        'p_txn_id': 'TEST_${DateTime.now().millisecondsSinceEpoch}',
        'p_order_id': 'ORD_${DateTime.now().millisecondsSinceEpoch}',
        'p_success': true,
        'p_signature_verified': true,
        'p_payload': {'source': 'paymob_test_client'},
      });
    } catch (rpcErr) {
      debugPrint('process_paymob_webhook direct call note: $rpcErr');
    }
  }

  /// Releases database lock on pending booking if payment expired or aborted.
  Future<void> releaseBookingLock(String bookingId) async {
    try {
      await _supabase.rpc('release_booking_lock', params: {
        'p_booking_id': bookingId,
      });
    } catch (e) {
      VSPLogger.e('Failed to release booking lock via RPC', e);
      rethrow;
    }
  }
}
