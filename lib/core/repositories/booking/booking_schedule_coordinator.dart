import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../services/logger_service.dart';
import 'booking_domain_rules.dart';

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
      if (depositPaid < 0) {
        throw Exception('لا يمكن إدخال عربون بقيمة سالبة.');
      }

      if (booking != null && booking.totalPrice > 0 && depositPaid > booking.totalPrice) {
        throw Exception(
          'قيمة العربون (${depositPaid.toStringAsFixed(0)} ج.م) لا يمكن أن تتجاوز إجمالي سعر الحجز (${booking.totalPrice.toStringAsFixed(0)} ج.م).',
        );
      }

      final normalized = BookingDomainRules.normalizeManualBookingPayment(
        depositPaid: depositPaid,
        totalPrice: booking?.totalPrice ?? 0,
        currentIsPaid: booking?.isPaid ?? false,
        currentIsDepositPaid: isDepositPaid,
        currentPaymentStatus: paymentStatus,
      );

      await _supabase.from('bookings').update({
        'player_team_name': name.trim(),
        'player_phone': phone.trim(),
        'notes': notes.trim(),
        'is_deposit_paid': normalized.isDepositPaid,
        'deposit_paid': depositPaid,
        'is_paid': normalized.isPaid,
        'payment_status': normalized.paymentStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', bookingId);
      return true;
    } catch (e) {
      VSPLogger.e('Error updating manual booking: $e', e);
      rethrow;
    }
  }

  /// Initiates a reschedule request from stadium owner.
  Future<bool> requestReschedule({
    required String bookingId,
    required DateTime newStartTime,
    required DateTime newEndTime,
  }) async {
    try {
      await _supabase.from('bookings').update({
        'reschedule_status': 'pending',
        'proposed_start_time': newStartTime.toUtc().toIso8601String(),
        'proposed_end_time': newEndTime.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', bookingId);
      return true;
    } catch (e) {
      VSPLogger.e('Error requesting reschedule', e);
      return false;
    }
  }

  /// Responds to a proposed reschedule (accept or reject).
  Future<bool> respondToReschedule({
    required Booking? booking,
    required String bookingId,
    required bool accept,
  }) async {
    try {
      if (booking == null) return false;

      if (accept && booking.proposedStartTime != null && booking.proposedEndTime != null) {
        final propStart = booking.proposedStartTime!.toUtc().toIso8601String();
        final propEnd = booking.proposedEndTime!.toUtc().toIso8601String();

        final conflictCheck = await _supabase
            .from('bookings')
            .select('id')
            .eq('stadium_id', booking.stadiumId)
            .neq('id', bookingId)
            .neq('status', 'cancelled')
            .filter('start_time', 'lt', propEnd)
            .filter('end_time', 'gt', propStart)
            .limit(1);

        if (conflictCheck.isNotEmpty) {
          VSPLogger.w('Reschedule slot conflict detected for stadium: ${booking.stadiumId}');
          await _supabase.from('bookings').update({
            'status': 'cancelled',
            'reschedule_status': 'conflict_auto_cancelled',
            'cancellation_reason': 'Proposed time was booked by another player',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', bookingId);
          return false;
        }

        await _supabase.from('bookings').update({
          'start_time': propStart,
          'end_time': propEnd,
          'reschedule_status': 'accepted',
          'proposed_start_time': null,
          'proposed_end_time': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', bookingId);
      } else {
        await _supabase.from('bookings').update({
          'status': 'cancelled',
          'reschedule_status': 'rejected',
          'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', bookingId);
      }
      return true;
    } catch (e) {
      VSPLogger.e('Error responding to reschedule', e);
      return false;
    }
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

  /// Cancels stale pending bookings for user and stadium.
  Future<void> cleanupStalePendingBookings({
    required String userId,
    required String stadiumId,
  }) async {
    try {
      await _supabase
          .from('bookings')
          .update({
            'status': 'cancelled',
            'payment_status': 'expired',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('created_by_user_id', userId)
          .eq('stadium_id', stadiumId)
          .eq('status', 'pending');
      debugPrint('Stale pending bookings transitioned to expired/cancelled safely.');
    } catch (e) {
      debugPrint('Error cleaning up stale bookings: $e');
    }
  }

  /// Simulates test payment webhook during development.
  Future<void> simulateTestPaymentWebhook(String bookingId) async {
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
    } catch (_) {
      await _supabase
          .from('bookings')
          .update({
            'status': 'cancelled',
            'payment_status': 'expired',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', bookingId)
          .eq('status', 'pending');
    }
  }
}
