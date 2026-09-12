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

  /// Cancels booking, triggers Paymob refund if applicable, and alerts involved parties.
  Future<bool> cancelBooking({
    required Booking? booking,
    required String bookingId,
  }) async {
    try {
      if (booking == null) return false;

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
          try {
            final res = await _supabase.functions.invoke('process_paymob_refund', body: {
              'booking_id': bookingId,
              'reason': 'User requested cancellation from app',
            });
            final data = res.data;
            if (data is Map && data['success'] == true) {
              VSPLogger.i('Paymob refund processed successfully for booking: $bookingId');
            } else {
              VSPLogger.w('Paymob refund notice for booking $bookingId: ${data?['message']}');
            }
          } catch (fnErr) {
            VSPLogger.w('process_paymob_refund invoke failed, falling back to atomic RPC: $fnErr');
            await _supabase.rpc('cancel_booking_with_refund_atomic', params: {
              'p_booking_id': bookingId,
              'p_user_id': _supabase.auth.currentUser?.id,
              'p_reason': 'User requested cancellation from app',
            });
          }
        } else {
          try {
            final rpcRes = await _supabase.rpc('cancel_booking_with_refund_atomic', params: {
              'p_booking_id': bookingId,
              'p_user_id': _supabase.auth.currentUser?.id,
              'p_reason': 'User requested cancellation from app',
            });
            if (rpcRes is Map && rpcRes['success'] == false) {
              VSPLogger.w('cancel_booking_with_refund_atomic message: ${rpcRes['message']}');
            }
          } catch (e) {
            VSPLogger.w('cancel_booking_with_refund_atomic fallback to update: $e');
            try {
              await _supabase
                  .from('bookings')
                  .update({
                    'status': BookingStatus.cancelled.name,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  })
                  .eq('id', bookingId);
            } on PostgrestException catch (pe) {
              if (pe.message.contains('cannot_cancel_within_6_hours') ||
                  pe.message.contains('cannot_cancel_within_2_hours') ||
                  pe.message.contains('6 ساعات')) {
                VSPLogger.w('Cannot cancel booking within 6 hours: ${pe.message}');
                return false;
              } else {
                rethrow;
              }
            }
          }
        }
      }

      // Notify other participants
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

      // Notify stadium owner
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
      return false;
    }
  }
}
