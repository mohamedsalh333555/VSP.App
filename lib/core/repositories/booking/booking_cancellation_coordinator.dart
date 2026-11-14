import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../services/logger_service.dart';
import '../../services/notification_handler.dart';

/// Handles booking cancellations, automated Paymob refunds, and push notifications to players/owner.
class BookingCancellationCoordinator {
  final SupabaseClient? _client;

  BookingCancellationCoordinator({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  static String sanitizeCancellationError(dynamic error, [String? serverMsg]) {
    final raw = serverMsg ?? error?.toString() ?? '';
    if (raw.contains('cannot_cancel_within_6_hours') || raw.contains('6 ساعات') || raw.contains('ساعتين') || raw.contains('cannot_cancel_within_2_hours')) {
      return 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات (إلا خلال أول 20 دقيقة من الحجز).';
    }
    if (raw.contains('cannot_cancel_completed_booking')) {
      return 'عذراً، لا يمكن إلغاء حجز لمباراة مكتملة تم حضورها بالفعل.';
    }
    if (raw.contains('forbidden') || raw.contains('غير مصرح')) {
      return 'غير مصرح لك بإلغاء هذا الحجز.';
    }
    if (raw.contains('already_cancelled') || raw.contains('ملغي بالفعل')) {
      return 'هذا الحجز ملغي بالفعل مسبقاً.';
    }
    if (serverMsg != null && serverMsg.trim().isNotEmpty) {
      final clean = serverMsg.trim();
      final lower = clean.toLowerCase();
      final exposesInternals = [
        'postgrest',
        'sqlstate',
        'relation ',
        'schema ',
        'column ',
        'constraint ',
        'function ',
        'stack trace',
        'exception:',
      ].any(lower.contains);
      if (!exposesInternals && clean.length <= 180) return clean;
    }
    return 'عذراً، تعذر إلغاء الحجز في الوقت الحالي.';
  }

  /// Cancels booking, triggers Paymob refund if applicable, and alerts involved parties.
  Future<bool> cancelBooking({
    required Booking? booking,
    required String bookingId,
  }) async {
    if (booking == null) {
      throw Exception('بيانات الحجز غير متوفرة.');
    }
    if (bookingId.trim().isEmpty) {
      throw ArgumentError('معرّف الحجز مطلوب لإتمام الإلغاء.');
    }
    if (booking.id != bookingId) {
      throw ArgumentError('معرّف الحجز لا يطابق بيانات الحجز المطلوب إلغاؤه.');
    }

    try {
      final bool isManual = booking.paymentTransactionId?.contains('MANUAL') ?? false;

      if (isManual) {
        try {
          final manualResult = await _supabase.rpc('owner_cancel_manual_booking_atomic', params: {
            'p_booking_id': bookingId,
            'p_owner_id': booking.ownerId,
            'p_refund_deposit': false,
          });
          if (manualResult is! Map || manualResult['success'] != true) {
            throw Exception(sanitizeCancellationError(
              null,
              manualResult is Map ? manualResult['message']?.toString() : null,
            ));
          }
        } catch (e) {
          // Never fall back to a direct bookings UPDATE: cancellation must pass
          // the server-side authorization/state/financial rules atomically.
          VSPLogger.e('Owner manual booking cancellation RPC failed (details redacted)');
          rethrow;
        }
      } else {
        final bool isPaidOnline = booking.isPaid || booking.isDepositPaid || booking.paymentStatus == 'paid';
        if (isPaidOnline && (booking.depositPaid > 0 || booking.totalPrice > 0)) {
          bool paymobProcessed = false;
          try {
            final res = await _supabase.functions.invoke('process_paymob_refund', body: {
              'booking_id': bookingId,
              'reason': 'User requested cancellation from app',
            });
            final data = res.data;
            if (data is Map && data['success'] == true) {
              VSPLogger.i('Paymob refund processed successfully (booking ID redacted)');
              paymobProcessed = true;
            } else if (data is Map &&
                data['refund_pending'] == true &&
                data['manual_review'] != true) {
              // The refund Edge Function can return success:false after it has
              // already cancelled the booking and queued/manualized the refund.
              // Confirm the persisted booking state before reporting cancellation success.
              final persisted = await _supabase
                  .from('bookings')
                  .select('status,payment_status')
                  .eq('id', bookingId)
                  .maybeSingle();
              if (persisted != null && persisted['status'] == 'cancelled') {
                VSPLogger.w('Booking cancelled; refund remains pending (booking ID redacted)');
                paymobProcessed = true;
              } else {
                final msg = data['message']?.toString();
                throw Exception(sanitizeCancellationError(null, msg));
              }
            } else {
              final msg = data is Map ? data['message']?.toString() : null;
              throw Exception(sanitizeCancellationError(null, msg));
            }
          } catch (fnErr) {
            if (paymobProcessed) rethrow;
            if (fnErr is Exception && !fnErr.toString().contains('FunctionException') && !fnErr.toString().contains('invoke failed')) {
              rethrow;
            }
            VSPLogger.w('Refund edge function unavailable; using atomic fallback (details redacted)');
            final rpcRes = await _supabase.rpc('cancel_booking_with_refund_atomic', params: {
              'p_booking_id': bookingId,
              'p_user_id': _supabase.auth.currentUser?.id,
              'p_reason': 'User requested cancellation from app',
            });
            if (rpcRes is! Map || rpcRes['success'] != true) {
              throw Exception(sanitizeCancellationError(
                null, rpcRes is Map ? rpcRes['message']?.toString() : null,
              ));
            }
          }
        } else {
          final rpcRes = await _supabase.rpc('cancel_booking_with_refund_atomic', params: {
            'p_booking_id': bookingId,
            'p_user_id': _supabase.auth.currentUser?.id,
            'p_reason': 'User requested cancellation from app',
          });
          if (rpcRes is! Map || rpcRes['success'] != true) {
            throw Exception(sanitizeCancellationError(
                null, rpcRes is Map ? rpcRes['message']?.toString() : null,
              ));
          }
        }
      }

      // Notify other participants ONLY after verified backend success
      final List<String> otherParticipants = booking.joinedUserIds
          .where((uid) => uid != booking.createdByUserId)
          .toList();

      if (otherParticipants.isNotEmpty) {
        try {
          await NotificationHandler.notifyMatchCancelledByHost(
            playerIds: otherParticipants,
            stadiumName: booking.stadiumName,
            timeSlot: booking.formattedTimeRange,
            bookingId: bookingId,
          );
        } catch (e) {
          VSPLogger.w('Cancellation notification dispatch failed (details redacted)');
        }
      }

      // Notify stadium owner ONLY after verified backend success
      if (booking.ownerId.isNotEmpty) {
        try {
          await NotificationHandler.notifyBookingCancelledByPlayer(
            ownerId: booking.ownerId,
            stadiumName: booking.stadiumName,
            playerName: booking.playerTeamName ?? booking.hostName ?? 'اللاعب',
            timeSlot: booking.formattedTimeRange,
            bookingId: bookingId,
          );
        } catch (e) {
          VSPLogger.w('Owner cancellation notification dispatch failed (details redacted)');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Booking cancellation failed (details redacted)');
      // Never expose raw PostgREST/SQL exceptions to the player.
      throw Exception(sanitizeCancellationError(e));
    }
  }
}
