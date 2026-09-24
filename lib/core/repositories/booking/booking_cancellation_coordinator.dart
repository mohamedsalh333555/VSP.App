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
    if (raw.contains('cannot_cancel_within_6_hours') || raw.contains('6 ساعات')) {
      return 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات (إلا خلال أول 20 دقيقة من الحجز).';
    }
    if (raw.contains('cannot_cancel_within_2_hours') || raw.contains('ساعتين')) {
      return 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من ساعتين وفقاً للائحة الملعب.';
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
      return serverMsg.trim();
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

    try {
      final bool isManual = booking.paymentTransactionId?.contains('MANUAL') ?? false;

      if (isManual) {
        await _supabase.from('bookings').update({
          'status': BookingStatus.cancelled.name,
          'cancellation_reason': 'Owner cancelled manual walk-in slot',
          'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', bookingId);
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
              VSPLogger.i('Paymob refund processed successfully for booking: $bookingId');
              paymobProcessed = true;
            } else {
              final msg = data is Map ? data['message']?.toString() : null;
              throw Exception(sanitizeCancellationError(null, msg));
            }
          } catch (fnErr) {
            if (paymobProcessed) rethrow;
            if (fnErr is Exception && !fnErr.toString().contains('FunctionException') && !fnErr.toString().contains('invoke failed')) {
              rethrow;
            }
            VSPLogger.w('process_paymob_refund invoke failed, falling back to atomic RPC: $fnErr');
            final rpcRes = await _supabase.rpc('cancel_booking_with_refund_atomic', params: {
              'p_booking_id': bookingId,
              'p_user_id': _supabase.auth.currentUser?.id,
              'p_reason': 'User requested cancellation from app',
            });
            if (rpcRes is Map && rpcRes['success'] == false) {
              throw Exception(sanitizeCancellationError(null, rpcRes['message']?.toString()));
            }
          }
        } else {
          final rpcRes = await _supabase.rpc('cancel_booking_with_refund_atomic', params: {
            'p_booking_id': bookingId,
            'p_user_id': _supabase.auth.currentUser?.id,
            'p_reason': 'User requested cancellation from app',
          });
          if (rpcRes is Map && rpcRes['success'] == false) {
            throw Exception(sanitizeCancellationError(null, rpcRes['message']?.toString()));
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
          );
        } catch (e) {
          VSPLogger.w('Failed to send cancellation notifications: $e');
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
          );
        } catch (e) {
          VSPLogger.w('Failed to send owner cancellation notification: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error cancelling booking: $e');
      // Never expose raw PostgREST/SQL exceptions to the player.
      throw Exception(sanitizeCancellationError(e));
    }
  }
}
