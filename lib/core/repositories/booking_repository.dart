import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../repositories/notification_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/team_repository.dart';
import '../services/analytics_service.dart';
import '../services/logger_service.dart';
import '../services/notification_handler.dart';
import '../services/paymob_service.dart';

/// Abstract BookingRepository interface
abstract class BookingRepository {
 /// Create a new booking from draft after payment success
 Future<Booking> createBooking(BookingDraft draft, String userId);

 /// Get all bookings for a user
 Stream<List<Booking>> getUserBookings(String userId);

 /// Direct REST fetch for user bookings
 Future<List<Booking>> getUserBookingsDirectly(String userId);

 /// Get all bookings for a stadium owner
 Stream<List<Booking>> getOwnerBookings(String ownerId, {List<String>? stadiumIds});

 /// Get a single booking by ID
 Future<Booking?> getBookingById(String bookingId);

 /// Update booking status
 Future<bool> updateBookingStatus(String bookingId, BookingStatus status);

 /// Cancel a booking
 Future<bool> cancelBooking(String bookingId);

 /// Get upcoming bookings for a user
 Stream<List<Booking>> getUpcomingBookings(String userId);

 /// Get completed/history bookings for a user
 Stream<List<Booking>> getBookingHistory(String userId);

 /// Submit match result for Challenge bookings
 Future<bool> submitMatchResult({
 required String bookingId,
 required String teamId,
 required MatchOutcome outcome,
 double? rating,
 String? review,
 });

 /// Update payment status
 Future<bool> updatePaymentStatus(String bookingId, bool isPaid);

 /// Get bookings for a specific stadium and date
 Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date);

 /// Auto-reconcile past bookings (Pivot Logic)
 Future<void> autoReconcilePastBookings(String ownerId);

 /// Get unpaid bookings for a user
 Future<List<Booking>> getUnpaidBookingsForUser(String userId);

 Future<void> autoExpirePendingChallenges();
 Future<void> autoReconcileSingleEntryResults();
 Future<void> autoNudgePostMatchResults();

 Future<bool> updateManualBooking({
 required String bookingId,
 required String name,
 required String phone,
 required String notes,
 required bool isDepositPaid,
 required double depositPaid,
 required String paymentStatus,
 });

 Future<bool> requestReschedule({
 required String bookingId,
 required DateTime newStartTime,
 required DateTime newEndTime,
 });

 Future<bool> respondToReschedule({
 required String bookingId,
 required bool accept,
 });

 Future<Map<String, dynamic>> requestEmergencyClosure({
 required String stadiumId,
 required String ownerId,
 required String reason,
 required int durationHours,
 });
}

/// Supabase implementation of BookingRepository
class SupabaseBookingRepository implements BookingRepository {
 final SupabaseClient _supabase = Supabase.instance.client;

 String _dbBookingType(BookingType type) {
 switch (type) {
 case BookingType.openJoin:
 return 'open_join';
 case BookingType.challenge:
 return 'challenge';
 case BookingType.team:
 return 'team';
 case BookingType.matchup:
 return 'matchup';
 case BookingType.personal:
 return 'personal';
 }
 }

 @override
 Future<Booking> createBooking(BookingDraft draft, String userId) async {
 try {
 // 1. إنشاء الحجز بشكل ذري مؤمّن ومباشر (Postgres Atomic RPC Lock)
 final platformFee = PaymobService.calculateServiceFee(draft.totalPrice);
 final rpcResult = await _supabase.rpc('create_booking_atomic', params: {
 'p_stadium_id': draft.stadiumId,
 'p_user_id': userId,
 'p_owner_id': draft.ownerId,
 'p_start_time': draft.startTime.toUtc().toIso8601String(),
 'p_end_time': draft.endTime.toUtc().toIso8601String(),
 'p_booking_type': _dbBookingType(draft.bookingType),
 'p_total_price': draft.totalPrice,
 'p_platform_fee': platformFee,
 'p_stadium_name': draft.stadiumName,
 'p_stadium_image_url': draft.stadiumImageUrl,
 'p_is_private': draft.isPrivate,
 'p_rent_ball': draft.rentBall,
 'p_needs_deposit': draft.needsDeposit,
 'p_deposit_amount': draft.depositPaid,
 'p_payment_method': draft.paymentMethod ?? 'cash',
 'p_payment_status': draft.paymentStatus ?? 'pending',
 'p_player_team_id': draft.playerTeamId,
 'p_player_team_name': draft.playerTeamName,
 'p_opponent_team_id': draft.opponentTeamId,
 'p_opponent_team_name': draft.opponentTeamName,
 });

    if (rpcResult is Map && rpcResult['success'] == false) {
      String errorMessage = rpcResult['message']?.toString() ?? "عذراً، هذا التوقيت محجوز بالفعل لمباراة أخرى.";
      final errorCode = rpcResult['code']?.toString();
      
      // Handle Supabase Windows-1252 encoding corruption (messages become '???')
      if (errorMessage.contains('???')) {
        if (errorCode == 'SLOT_LOCKED_OR_TAKEN') {
          errorMessage = "عذراً، هذا الموعد محجوز أو قيد الدفع من قِبل لاعب آخر حالياً.";
        } else if (errorMessage.contains('????? ???? ?? ????? ??????')) {
          errorMessage = "حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.";
        } else if (errorMessage.contains('???? ??? ???? ??? ??????')) {
          errorMessage = "لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.";
        } else if (errorMessage.contains('????? ???? ??????')) {
          errorMessage = "حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.";
        } else {
          errorMessage = "عذراً، تعذر إتمام الحجز. يرجى التأكد من الموعد والمحاولة لاحقاً.";
        }
      }
      
      throw Exception(errorMessage);
    }

 final bookingId = (rpcResult is Map) ? rpcResult['booking_id']?.toString() : null;
 if (bookingId == null) {
 throw Exception("فشل تسجيل الحجز في قاعدة البيانات.");
 }

 final created = await getBookingById(bookingId);
 if (created == null) throw Exception("تعذر جلب تفاصيل الحجز بعد الإنشاء.");

 if (draft.bookingType == BookingType.challenge && draft.opponentTeamId != null) {
 _sendChallengeNotification(draft);
 }
 if (created.status == BookingStatus.confirmed || draft.paymentMethod == 'cash') {
 _sendOwnerNotification(draft, created.id);
 }

 AnalyticsService.logStadiumBooked(draft.stadiumId, draft.totalPrice);
 VSPLogger.i(' Atomic booking created: ${created.id}');
 return created;
 } on PostgrestException catch (e) {
 if (e.code == '23P11' || e.message.contains('overlapping') || e.message.contains('exclude') || e.code == '23505') {
 throw Exception("عذراً، هذا التوقيت محجوز بالفعل لمباراة أخرى.");
 }
 rethrow;
 } catch (e) {
 VSPLogger.e(' Error creating booking', e);
 rethrow;
 }
 }

 Future<void> _sendOwnerNotification(BookingDraft draft, String bookingId) async {
 try {
 final dateStr = DateFormat('MMM d', 'en').format(draft.startTime);
 final timeStr = DateFormat('h:mm a', 'en').format(draft.startTime);
 await NotificationRepository().sendNotification(
 draft.ownerId,
 AppNotification(
 id: '',
 title: 'New Booking Received! ',
 body: '${draft.playerTeamName ?? "A player"} booked ${draft.stadiumName} on $dateStr at $timeStr.',
 type: 'info',
 createdAt: DateTime.now(),
 bookingId: bookingId,
 ),
 );
 } catch (e) {
 debugPrint('Error sending owner notification: $e');
 }
 }

 Future<void> _sendChallengeNotification(BookingDraft draft) async {
 try {
 if (draft.opponentTeamId == null) return;
 // 1. Get opponent team from Supabase
 final team = await TeamRepository().getTeam(draft.opponentTeamId!);
 if (team == null) return;
 
 final captainPhone = team.captainPhone;
 if (captainPhone == null || captainPhone.isEmpty) return;

 // 2. Find captain user ID by phone
 final captainUser = await UserRepository().getUserByPhone(captainPhone);
 if (captainUser == null) return;

 // 3. Send notification
 await NotificationRepository().sendNotification(
 captainUser.uid,
 AppNotification(
 id: '', 
 title: 'Challenge Confirmed!',
 body: 'You are playing against ${draft.playerTeamName ?? "another team"} at ${draft.stadiumName} on ${DateFormat('MMM d').format(draft.startTime)}.',
 type: 'info',
 createdAt: DateTime.now(),
 ),
 );
 AnalyticsService.logChallengeSent(draft.playerTeamId ?? 'unknown', draft.opponentTeamId!);
 } catch (e) {
 VSPLogger.e('Error sending challenge notification', e);
 }
 }

  @override
  Stream<List<Booking>> getUserBookings(String userId) async* {
    // 1. Immediate REST fetch
    final direct = await getUserBookingsDirectly(userId);
    if (direct.isNotEmpty) yield direct;

    // 2. Realtime stream with safety timeout & error recovery
    yield* _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('created_by_user_id', userId)
        .map((list) {
          final bookings = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .toList();
          bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
          return bookings;
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await getUserBookingsDirectly(userId);
            sink.add(refreshed);
          },
        )
        .handleError((error) {
          VSPLogger.w('Handled realtime error in getUserBookings: $error');
        });
  }

 @override
 Future<List<Booking>> getUserBookingsDirectly(String userId) async {
 try {
 final bool isValidId = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(userId);
 if (!isValidId) return [];

 final response = await _supabase
 .from('bookings')
 .select()
 .or('user_id.eq.$userId,created_by_user_id.eq.$userId,joined_user_ids.cs.{"$userId"}')
 .order('start_time', ascending: false)
 .limit(100);
 final bookings = (response as List)
 .map((data) => Booking.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
 .where((b) => b.userId.trim().toLowerCase() == userId.trim().toLowerCase() || b.joinedUserIds.map((e) => e.trim().toLowerCase()).contains(userId.trim().toLowerCase()))
 .toList();
 VSPLogger.i(' getUserBookingsDirectly returned ${bookings.length} bookings');
 return bookings;
 } catch (e) {
 VSPLogger.e(' Error in getUserBookingsDirectly: $e');
 return [];
 }
 }

 Future<List<Booking>> fetchOwnerBookingsDirectly(String ownerId, {List<String>? stadiumIds}) async {
 try {
 var query = _supabase.from('bookings').select();
 
 if (stadiumIds != null && stadiumIds.isNotEmpty) {
 query = query.inFilter('stadium_id', stadiumIds);
 } else {
 query = query.eq('owner_id', ownerId);
 }

    final response = await query.order('start_time', ascending: false).limit(100);
 final bookings = (response as List)
 .map((data) => Booking.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
 .toList();
 
 VSPLogger.i(' Direct REST fetch returned ${bookings.length} bookings');
 return bookings;
 } catch (e) {
 VSPLogger.e(' Error fetching owner bookings directly: $e');
 return [];
 }
 }

  @override
  Stream<List<Booking>> getOwnerBookings(String ownerId, {List<String>? stadiumIds}) async* {
    final lowerStadiumIds = stadiumIds?.map((id) => id.toLowerCase()).toList();

    // 1. Immediate REST fetch
    final direct = await fetchOwnerBookingsDirectly(ownerId, stadiumIds: stadiumIds);
    if (direct.isNotEmpty) yield direct;

    // 2. Realtime stream with safety timeout & error recovery
    yield* _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .limit(100)
        .map((list) {
          final bookings = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) {
                if (lowerStadiumIds != null && lowerStadiumIds.isNotEmpty) {
                  return lowerStadiumIds.contains(b.stadiumId.toLowerCase());
                }
                return true;
              })
              .toList();
          bookings.sort((a, b) => b.startTime.compareTo(a.startTime));
          return bookings;
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await fetchOwnerBookingsDirectly(ownerId, stadiumIds: stadiumIds);
            sink.add(refreshed);
          },
        )
        .handleError((error) {
          VSPLogger.w('Handled realtime error in getOwnerBookings: $error');
        });
  }

 @override
 Future<Booking?> getBookingById(String bookingId) async {
 try {
 final response = await _supabase
 .from('bookings')
 .select()
 .eq('id', bookingId)
 .maybeSingle();
 if (response != null) {
 return Booking.fromFirestore(response, response['id'].toString());
 }
 return null;
 } catch (e) {
 debugPrint(' Error getting booking: $e');
 return null;
 }
 }

 @override
 Future<bool> updateBookingStatus(String bookingId, BookingStatus status) async {
 try {
 await _supabase
 .from('bookings')
 .update({
 'status': status.name,
 'updated_at': DateTime.now().toUtc().toIso8601String(),
 })
 .eq('id', bookingId);
 return true;
 } catch (e) {
 debugPrint(' Error updating booking status: $e');
 return false;
 }
 }

 @override
 Future<bool> cancelBooking(String bookingId) async {
 try {
 final booking = await getBookingById(bookingId);
 if (booking == null) return false;

 final bool isManual = booking.paymentTransactionId?.contains('MANUAL') ?? false;

        if (isManual) {
          // Stadium Owner cancelling a manual walk-in slot: Safe soft-cancellation
          await _supabase.from('bookings').update({
            'status': BookingStatus.cancelled.name,
            'cancellation_reason': 'Owner cancelled manual walk-in slot',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', bookingId);
        } else {
          final bool isPaidOnline = booking.isPaid || booking.isDepositPaid || booking.paymentStatus == 'paid';
          if (isPaidOnline && (booking.depositPaid > 0 || booking.totalPrice > 0)) {
            // استدعاء process_paymob_refund Edge Function لاسترداد المبلغ عبر Paymob
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
                if (pe.message.contains('cannot_cancel_within_2_hours')) {
                  VSPLogger.w('Cannot cancel booking within 2 hours: ${pe.message}');
                  return false;
                } else {
                  rethrow;
                }
              }
            }
          }
        }

 // ── Notify Joined Participants ──
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
 VSPLogger.w(' Failed to send cancellation notifications: $e');
 }
 }

 // إشعار مالك الملعب بإلغاء الحجز
 if (booking.ownerId.isNotEmpty) {
 try {
 await NotificationHandler.notifyBookingCancelledByPlayer(
 ownerId: booking.ownerId,
 stadiumName: booking.stadiumName,
 playerName: booking.playerTeamName ?? booking.hostName ?? 'اللاعب',
 timeSlot: booking.formattedTimeRange,
 );
 } catch (e) {
 VSPLogger.w(' Failed to send owner cancellation notification: $e');
 }
 }

 return true;
 } catch (e) {
 debugPrint(' Error cancelling booking: $e');
 return false;
 }
 }

  @override
  Stream<List<Booking>> getUpcomingBookings(String userId) {
    final now = DateTime.now();
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('created_by_user_id', userId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .map((list) {
          final bookings = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) => b.status == BookingStatus.confirmed && b.startTime.isAfter(now))
              .toList();
          bookings.sort((a, b) => a.startTime.compareTo(b.startTime));
          return bookings;
        })
        .handleError((error) {
          VSPLogger.w('Handled realtime error in getUpcomingBookings: $error');
        });
  }

  @override
  Stream<List<Booking>> getBookingHistory(String userId) {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('created_by_user_id', userId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .map((list) {
          final bookings = list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) => b.status == BookingStatus.completed)
              .toList();
          bookings.sort((a, b) => a.startTime.compareTo(b.startTime));
          return bookings;
        })
        .handleError((error) {
          VSPLogger.w('Handled realtime error in getBookingHistory: $error');
        });
  }

 @override
 Future<bool> submitMatchResult({
 required String bookingId,
 required String teamId,
 required MatchOutcome outcome,
 double? rating,
 String? review,
 }) async {
 try {
 final booking = await getBookingById(bookingId);
 if (booking == null) return false;

 // Elo Fraud Prevention: Time-Lock Result Submission
 if (DateTime.now().toUtc().isBefore(booking.endTime.toUtc())) {
 VSPLogger.w(' Result submission blocked: Match has not ended yet for booking $bookingId');
 throw Exception("Cannot submit results before the match officially ends.");
 }

 final currentMatchStatus = booking.matchResultStatus;
 final submittedBy = booking.resultSubmittedByTeamId;

 Future<void> saveRating() async {
 if (rating != null && rating > 0) {
 final effectiveUserId = _supabase.auth.currentUser?.id ?? booking.createdByUserId;

 // 1. تحقق من عدم تكرار التقييم لنفس الملعب والمستخدم في Supabase
 final existing = await _supabase
 .from('reviews')
 .select('id')
 .eq('stadium_id', booking.stadiumId)
 .eq('user_id', effectiveUserId)
 .maybeSingle();

 if (existing != null) {
 VSPLogger.i(' Skipping duplicate review submission for booking $bookingId');
 return;
 }

 // جلب بيانات البروفايل لمنع التقييمات مجهولة الهوية
 String userName = 'لاعب VSP';
 String userImageUrl = '';
 try {
 final userDoc = await UserRepository().getUserData(effectiveUserId);
 if (userDoc != null) {
 userName = userDoc['name'] ?? userName;
 userImageUrl = userDoc['profile_image_url'] ?? '';
 }
 } catch (_) {}

 // 2. إدراج التقييم الجديد في جدول reviews في Supabase
 await _supabase.from('reviews').insert({
 'stadium_id': booking.stadiumId,
 'user_id': effectiveUserId,
 'user_name': userName,
 'user_image_url': userImageUrl,
 'rating': rating.toInt(),
 'review_text': review ?? '',
 'created_at': DateTime.now().toUtc().toIso8601String(),
 });
 
 VSPLogger.i(' Stadium review inserted. DB Trigger will update rating average.');
 }
 }

 // Case A: First submission (no result yet) OR Captain 1 editing/changing their submitted result
 if (currentMatchStatus == MatchResultStatus.noResult || submittedBy == teamId) {
 await _supabase.from('bookings').update({
 'pending_outcome': outcome.name,
 'result_submitted_by_team_id': teamId,
 'match_result_status': MatchResultStatus.waitingOpponent.name,
 'requires_admin_intervention': false,
 'final_outcome': null,
 'updated_at': DateTime.now().toUtc().toIso8601String(),
 }).eq('id', bookingId);
 await saveRating();
 return true;
 } 
 // Case B: Captain 2 responding (status is waitingOpponent or disputed)
 else if (submittedBy != teamId) {
 final pendingOutcomeStr = booking.pendingOutcome?.name;

 // Agreement by Captain 2 with Captain 1's claimed outcome
 if (pendingOutcomeStr == outcome.name) {
 await _supabase.from('bookings').update({
 'final_outcome': outcome.name,
 'match_result_status': MatchResultStatus.confirmed.name,
 'status': BookingStatus.completed.name,
 'requires_admin_intervention': false, // Dispute automatically resolved!
 'pending_outcome': null,
 'result_submitted_by_team_id': null,
 'updated_at': DateTime.now().toUtc().toIso8601String(),
 }).eq('id', bookingId);

 await saveRating();
 return true;
 } else {
 // Disagreement / Dispute by Captain 2
 await _supabase.from('bookings').update({
 'match_result_status': MatchResultStatus.disputed.name,
 'requires_admin_intervention': true,
 'updated_at': DateTime.now().toUtc().toIso8601String(),
 }).eq('id', bookingId);
 await saveRating();
 return false;
 }
 }
 return false;
    } catch (e) {
      debugPrint(' Error submitting match result: $e');
      return false;
    }
  }


  Future<List<Booking>> fetchStadiumBookingsDirectly(String stadiumId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 2));

      final response = await _supabase
          .from('bookings')
          .select()
          .eq('stadium_id', stadiumId)
          .gte('start_time', startOfDay.toIso8601String())
          .lt('start_time', endOfDay.toIso8601String());

      return (response as List)
          .map((data) => Booking.fromFirestore(data as Map<String, dynamic>, data['id'].toString()))
          .where((b) {
            if (b.status == BookingStatus.cancelled) return false;
            if (b.status == BookingStatus.pending) {
              final createdAtLocal = b.createdAt.toLocal();
              final isExpired = DateTime.now().difference(createdAtLocal).inMinutes >= 5;
              if (isExpired) return false;
            }
            return true;
          })
          .toList();
    } catch (e) {
      VSPLogger.w('fetchStadiumBookingsDirectly notice: $e');
      return [];
    }
  }

  @override
  Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date) async* {
    // 1. Immediate REST API fetch
    final direct = await fetchStadiumBookingsDirectly(stadiumId, date);
    if (direct.isNotEmpty) yield direct;

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 2));

    // 2. Realtime Stream with safety timeout & error recovery
    yield* _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('stadium_id', stadiumId)
        .map((list) {
          return list
              .map((data) => Booking.fromFirestore(data, data['id'].toString()))
              .where((b) {
                if (b.status == BookingStatus.cancelled) return false;

                // Fix: If booking is pending and older than 5 minutes without payment, ignore it (does not block slot)
                if (b.status == BookingStatus.pending) {
                  final createdAtLocal = b.createdAt.toLocal();
                  final isExpired = DateTime.now().difference(createdAtLocal).inMinutes >= 5;
                  if (isExpired) return false;
                }

                return b.startTime.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
                    b.startTime.isBefore(endOfDay);
              })
              .toList();
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await fetchStadiumBookingsDirectly(stadiumId, date);
            sink.add(refreshed);
          },
        )
        .handleError((error) {
          VSPLogger.w('Handled realtime error in getBookingsForStadium: $error');
        });
  }

 @override
 Future<bool> updatePaymentStatus(String bookingId, bool isPaid) async {
 try {
 final b = await getBookingById(bookingId);
 if (b == null) return false;

 if (isPaid) {
 final rpcRes = await _supabase.rpc('confirm_cash_booking_atomic', params: {
 'p_booking_id': bookingId,
 'p_owner_id': b.ownerId,
 'p_total_price': b.totalPrice,
 });

 if (rpcRes is Map && rpcRes['success'] == false) {
 VSPLogger.w('RPC confirm_cash_booking_atomic returned error: ${rpcRes['message']}');
 return false;
 }

 try {
 await NotificationHandler.notifyPaymentReceived(
 recipientId: b.ownerId,
 userName: b.hostName ?? 'لاعب',
 amount: b.totalPrice,
 bookingId: bookingId,
 );
 } catch (e) {
 VSPLogger.w('Skip payment notification: $e');
 }
 }
 return true;
 } catch (e) {
 debugPrint(' Error updating payment status via RPC: $e');
 return false;
 }
 }

 @override
 Future<void> autoReconcilePastBookings(String ownerId) async {
 try {
 await _supabase.rpc('auto_reconcile_past_bookings');
 VSPLogger.i(' auto_reconcile_past_bookings RPC executed successfully');
 } catch (e) {
 VSPLogger.e(' Error in autoReconcilePastBookings RPC', e);
 }
 }

 @override
 Future<List<Booking>> getUnpaidBookingsForUser(String userId) async {
 try {
 final nowUtcIso = DateTime.now().toUtc().toIso8601String();
 final response = await _supabase
 .from('bookings')
 .select()
 .eq('created_by_user_id', userId)
 .eq('is_paid', false)
 .gte('end_time', nowUtcIso)
 .neq('status', 'cancelled')
 .neq('status', 'completed');
 
 return (response as List)
 .map((doc) => Booking.fromFirestore(doc as Map<String, dynamic>, doc['id'].toString()))
 .toList();
 } catch (e) {
 VSPLogger.e('Error fetching unpaid bookings for user $userId', e);
 return [];
 }
 }

 @override
 Future<void> autoExpirePendingChallenges() async {
 try {
 final response = await _supabase
 .from('bookings')
 .select()
 .eq('booking_type', BookingType.challenge.name)
 .eq('status', BookingStatus.pending.name);

 final now = DateTime.now();
 for (final doc in (response as List)) {
 final booking = Booking.fromFirestore(doc, doc['id'].toString());
 final createdAt = booking.createdAt;
 final startTime = booking.startTime;

 bool shouldExpire = false;
 if (now.difference(createdAt).inHours >= 4) {
 shouldExpire = true;
 } else if (startTime.difference(now).inHours <= 12) {
 shouldExpire = true;
 }

 if (shouldExpire) {
 await _supabase.from('bookings').update({
 'status': BookingStatus.cancelled.name,
 'updated_at': now.toUtc().toIso8601String(),
 }).eq('id', booking.id);

 await NotificationRepository().sendNotification(
 booking.createdByUserId,
 AppNotification(
 id: '',
 title: " إلغاء التحدي تلقائياً / Challenge Expired",
 body: "انتهت مهلة التحدي لعدم رد الخصم، تم إلغاء الحجز تلقائياً لتتمكن من تحدي فريق آخر",
 type: "info",
 createdAt: DateTime.now(),
 ),
 );
 }
 }
 } catch (e) {
 VSPLogger.e('Error in autoExpirePendingChallenges', e);
 }
 }

 @override
 Future<void> autoReconcileSingleEntryResults() async {
 try {
 final response = await _supabase
 .from('bookings')
 .select()
 .eq('booking_type', BookingType.challenge.name)
 .eq('match_result_status', MatchResultStatus.waitingOpponent.name);

 final now = DateTime.now();
 for (final doc in (response as List)) {
 final booking = Booking.fromFirestore(doc, doc['id'].toString());
 final updatedAt = booking.updatedAt ?? booking.createdAt;

 // 24-Hour Threshold (Product Manager & User Approved)
 if (now.difference(updatedAt).inHours >= 24) {
 final outcome = booking.pendingOutcome ?? MatchOutcome.draw;
 final homeTeamId = booking.playerTeamId;
 final awayTeamId = booking.opponentTeamId;

 if (homeTeamId != null && awayTeamId != null) {
 // 1. Resolve match with the submitted outcome
 await TeamRepository().updateMatchResult(
 booking.id,
 homeTeamId,
 awayTeamId,
 outcome,
 );

 // 2. Identify the non-responding team and apply 5% Fair Play penalty
 final submittedBy = booking.resultSubmittedByTeamId;
 final nonRespondingTeamId = (submittedBy == homeTeamId) ? awayTeamId : homeTeamId;

 // Fetch non-responding team data
 final teamDoc = await _supabase
 .from('teams')
 .select('fair_play_score')
 .eq('id', nonRespondingTeamId)
 .maybeSingle();

 if (teamDoc != null) {
 final currentFairPlay = (teamDoc['fair_play_score'] as int?) ?? 100;
 // Deduct 5% (5 points out of 100)
 final newFairPlay = (currentFairPlay - 5).clamp(0, 100);

 await _supabase
 .from('teams')
 .update({'fair_play_score': newFairPlay})
 .eq('id', nonRespondingTeamId);

 VSPLogger.i(' Fair Play Penalty Applied: Team $nonRespondingTeamId penalized to $newFairPlay% due to no-response for 5 days.');
 }
 }

 // 3. Confirm booking status
 await _supabase.from('bookings').update({
 'match_result_status': MatchResultStatus.confirmed.name,
 'status': BookingStatus.completed.name,
 'final_outcome': outcome.name,
 'pending_outcome': null,
 'result_submitted_by_team_id': null,
 'updated_at': now.toUtc().toIso8601String(),
 }).eq('id', booking.id);
 }
 }
 } catch (e) {
 VSPLogger.e('Error in autoReconcileSingleEntryResults', e);
 }
 }

 @override
 Future<void> autoNudgePostMatchResults() async {
 try {
 final response = await _supabase
 .from('bookings')
 .select()
 .eq('booking_type', BookingType.challenge.name)
 .eq('match_result_status', MatchResultStatus.noResult.name)
 .eq('status', BookingStatus.confirmed.name);

 final now = DateTime.now();
 for (final doc in (response as List)) {
 final booking = Booking.fromFirestore(doc, doc['id'].toString());
 final endTime = booking.endTime;
 final notes = booking.notes ?? '';

 if (now.isAfter(endTime.add(const Duration(hours: 1))) && !notes.contains('[NUDGED]')) {
 await NotificationRepository().sendNotification(
 booking.createdByUserId,
 AppNotification(
 id: '',
 title: " تسجيل نتيجة المباراة / Submit Match Result",
 body: "انتهت مباراتك الرائعة ضد ${booking.opponentTeamName ?? 'الخصم'}! يرجى إدخال النتيجة الآن لتحديث ترتيب فريقك وتجنب تعليق نقاطك.",
 type: "info",
 createdAt: DateTime.now(),
 ),
 );

 final opponentTeamId = booking.opponentTeamId;
 if (opponentTeamId != null) {
 final opponentTeam = await TeamRepository().getTeam(opponentTeamId);
 final captainPhone = opponentTeam?.captainPhone;
 if (captainPhone != null && captainPhone.isNotEmpty) {
 final captainUser = await UserRepository().getUserByPhone(captainPhone);
 if (captainUser != null) {
 await NotificationRepository().sendNotification(
 captainUser.uid,
 AppNotification(
 id: '',
 title: " تسجيل نتيجة المباراة / Submit Match Result",
 body: "انتهت مباراتك الرائعة ضد ${booking.playerTeamName ?? 'الخصم'}! يرجى إدخال النتيجة الآن لتحديث ترتيب فريقك وتجنب تعليق نقاطك.",
 type: "info",
 createdAt: DateTime.now(),
 ),
 );
 }
 }
 }

 await _supabase.from('bookings').update({
 'notes': '$notes [NUDGED]'.trim(),
 'updated_at': now.toUtc().toIso8601String(),
 }).eq('id', booking.id);
 }
 }
 } catch (e) {
 VSPLogger.e('Error in autoNudgePostMatchResults', e);
 }
 }
  @override
  Future<bool> updateManualBooking({
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

      final booking = await getBookingById(bookingId);
      if (booking != null && booking.totalPrice > 0 && depositPaid > booking.totalPrice) {
        throw Exception('قيمة العربون (${depositPaid.toStringAsFixed(0)} ج.م) لا يمكن أن تتجاوز إجمالي سعر الحجز (${booking.totalPrice.toStringAsFixed(0)} ج.م).');
      }

      // ضبط تلقائي متسق لحالة الدفع لمنع التناقض المالي
      String normalizedPaymentStatus = paymentStatus;
      bool normalizedIsPaid = booking?.isPaid ?? false;
      bool normalizedIsDepositPaid = isDepositPaid;

      if (booking != null && booking.totalPrice > 0) {
        if (depositPaid >= booking.totalPrice) {
          normalizedPaymentStatus = 'paid';
          normalizedIsPaid = true;
          normalizedIsDepositPaid = true;
        } else if (depositPaid > 0) {
          normalizedPaymentStatus = 'deposit_paid';
          normalizedIsDepositPaid = true;
        }
      }

      await _supabase.from('bookings').update({
        'player_team_name': name.trim(),
        'player_phone': phone.trim(),
        'notes': notes.trim(),
        'is_deposit_paid': normalizedIsDepositPaid,
        'deposit_paid': depositPaid,
        'is_paid': normalizedIsPaid,
        'payment_status': normalizedPaymentStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', bookingId);
      return true;
    } catch (e) {
      VSPLogger.e('Error updating manual booking: $e', e);
      rethrow;
    }
  }

 /// 2. طلب ترحيل الموعد من قِبل المالك
 @override
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

 /// 3. استجابة اللاعب لطلب ترحيل الموعد
 @override
 Future<bool> respondToReschedule({
 required String bookingId,
 required bool accept,
 }) async {
 try {
 final booking = await getBookingById(bookingId);
 if (booking == null) return false;

 if (accept && booking.proposedStartTime != null && booking.proposedEndTime != null) {
 final propStart = booking.proposedStartTime!.toUtc().toIso8601String();
 final propEnd = booking.proposedEndTime!.toUtc().toIso8601String();

 // Overlap Guard: Ensure proposed slot is still 100% free before updating
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

 /// 4. طلب الإغلاق الطارئ للملعب (مرة واحدة شهرياً للمالك)
 @override
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
}

/// Mock implementation for demo/testing
class MockBookingRepository implements BookingRepository {
 final List<Booking> _bookings = [];
 final _controller = StreamController<List<Booking>>.broadcast();

 @override
 Future<bool> requestReschedule({
 required String bookingId,
 required DateTime newStartTime,
 required DateTime newEndTime,
 }) async => true;

 @override
 Future<bool> respondToReschedule({
 required String bookingId,
 required bool accept,
 }) async => true;

 @override
 Future<Map<String, dynamic>> requestEmergencyClosure({
 required String stadiumId,
 required String ownerId,
 required String reason,
 required int durationHours,
 }) async => {'success': true};

 void _update() {
 _controller.add(List.from(_bookings));
 }

 @override
 Future<Booking> createBooking(BookingDraft draft, String userId) async {
 await Future.delayed(const Duration(milliseconds: 500)); // Simulate network
 
 // For the Cash-Only MVP, we auto-confirm all bookings.
 const status = BookingStatus.confirmed;

 final booking = Booking.fromDraft(
 id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
 draft: draft,
 userId: userId,
 status: status,
 );

 _bookings.add(booking);
 _update();
 debugPrint(' Mock Booking created: ${booking.id}');
 return booking;
 }

 @override
 Stream<List<Booking>> getUserBookings(String userId) async* {
 yield _bookings.where((b) => b.createdByUserId == userId).toList();
 yield* _controller.stream.map(
 (bookings) => bookings.where((b) => b.createdByUserId == userId).toList(),
 );
 }

 @override
 Future<List<Booking>> getUserBookingsDirectly(String userId) async {
 return _bookings.where((b) => b.createdByUserId == userId || b.userId == userId).toList();
 }

 @override
 Stream<List<Booking>> getOwnerBookings(String ownerId, {List<String>? stadiumIds}) async* {
 yield _bookings.where((b) => b.ownerId == ownerId).toList();
 yield* _controller.stream.map(
 (bookings) => bookings.where((b) => b.ownerId == ownerId).toList(),
 );
 }

 @override
 Future<Booking?> getBookingById(String bookingId) async {
 try {
 return _bookings.firstWhere((b) => b.id == bookingId);
 } catch (_) {
 return null;
 }
 }

 @override
 Future<bool> updateBookingStatus(
 String bookingId, BookingStatus status) async {
 final index = _bookings.indexWhere((b) => b.id == bookingId);
 if (index != -1) {
 _bookings[index] = _bookings[index].copyWith(status: status);
 _update();
 }
 return true;
 }

 @override
 Future<bool> cancelBooking(String bookingId) async {
 return updateBookingStatus(bookingId, BookingStatus.cancelled);
 }

 @override
 Stream<List<Booking>> getUpcomingBookings(String userId) {
 final now = DateTime.now();
 return getUserBookings(userId).map(
 (bookings) => bookings
 .where((b) =>
 b.status == BookingStatus.confirmed &&
 b.startTime.isAfter(now))
 .toList(),
 );
 }

 @override
 Stream<List<Booking>> getBookingHistory(String userId) {
 return getUserBookings(userId).map(
 (bookings) => bookings
 .where((b) =>
 b.status == BookingStatus.completed || b.isCompleted)
 .toList(),
 );
 }

 @override
 Future<bool> submitMatchResult({
 required String bookingId,
 required String teamId,
 required MatchOutcome outcome,
 double? rating,
 String? review,
 }) async {
 final index = _bookings.indexWhere((b) => b.id == bookingId);
 if (index == -1) return false;

 final booking = _bookings[index];
 
 if (booking.matchResultStatus == MatchResultStatus.noResult) {
 _bookings[index] = booking.copyWith(
 pendingOutcome: outcome,
 resultSubmittedByTeamId: teamId,
 matchResultStatus: MatchResultStatus.waitingOpponent,
 );
 _update();
 return true;
 } else if (booking.matchResultStatus == MatchResultStatus.waitingOpponent && 
 booking.resultSubmittedByTeamId != teamId) {
 if (booking.pendingOutcome == outcome) {
 _bookings[index] = booking.copyWith(
 finalOutcome: outcome,
 matchResultStatus: MatchResultStatus.confirmed,
 status: BookingStatus.completed,
 pendingOutcome: null,
 resultSubmittedByTeamId: null,
 );
 
 // Squads & Challenges: Disable Automated Client-Side Elo updates
 // Points/Elo calculation is completely offloaded to Supabase to execute only upon owner verification.
 /*
 if (booking.playerTeamId != null && booking.opponentTeamId != null) {
 TeamRepository().updateMatchResult(
 bookingId, 
 booking.playerTeamId!, 
 booking.opponentTeamId!, 
 outcome
 );
 }
 */

 _update();
 return true;
 } else {
 _bookings[index] = booking.copyWith(
 matchResultStatus: MatchResultStatus.disputed,
 );
 _update();
 return false;
 }
 }
 return false;
 }

 @override
 Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date) {
 final startOfDay = DateTime(date.year, date.month, date.day);
 final endOfDay = startOfDay.add(const Duration(days: 1));

 return Stream.value(_bookings
 .where((b) =>
 b.stadiumId == stadiumId &&
 b.startTime.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
 b.startTime.isBefore(endOfDay) &&
 b.status != BookingStatus.cancelled)
 .toList());
 }

 @override
 Future<bool> updatePaymentStatus(String bookingId, bool isPaid) async {
 final index = _bookings.indexWhere((b) => b.id == bookingId);
 if (index != -1) {
 _bookings[index] = _bookings[index].copyWith(isPaid: isPaid);
 _update();
 }
 return true;
 }

 @override
 Future<void> autoReconcilePastBookings(String ownerId) async {
 // Mock implementation not strictly necessary for this task but good for consistency
 return;
 }

 @override
 Future<List<Booking>> getUnpaidBookingsForUser(String userId) async {
 return _bookings.where((b) => b.createdByUserId == userId && !b.isPaid).toList();
 }

 @override
 Future<void> autoExpirePendingChallenges() async {}

 @override
 Future<void> autoReconcileSingleEntryResults() async {}

 @override
 Future<void> autoNudgePostMatchResults() async {}

 @override
 Future<bool> updateManualBooking({
 required String bookingId,
 required String name,
 required String phone,
 required String notes,
 required bool isDepositPaid,
 required double depositPaid,
 required String paymentStatus,
 }) async {
 return true;
 }

 /// Add mock bookings for testing
 void addMockBookings() {
 final now = DateTime.now();
 
 // Upcoming booking
 _bookings.add(Booking(
 id: 'mock_1',
 stadiumId: '1',
 stadiumName: 'Santiago Bernabéu',
 stadiumImageUrl: 'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?w=800',
 ownerId: 'owner_1',
 startTime: now.add(const Duration(days: 2, hours: 3)),
 endTime: now.add(const Duration(days: 2, hours: 5)),
 bookingType: BookingType.personal,
 isPrivate: false,
 rentBall: true,
 totalPrice: 140,
 paymentMethod: 'card',
 status: BookingStatus.confirmed,
 createdByUserId: 'demo_user',
 createdAt: now.subtract(const Duration(days: 1)),
 ));

 // Completed booking
 _bookings.add(Booking(
 id: 'mock_2',
 stadiumId: '2',
 stadiumName: 'Camp Nou',
 stadiumImageUrl: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800',
 ownerId: 'owner_2',
 startTime: now.subtract(const Duration(days: 5, hours: 3)),
 endTime: now.subtract(const Duration(days: 5, hours: 1)),
 bookingType: BookingType.team,
 playerTeamId: 'team_1',
 playerTeamName: 'Real Madrid CF',
 isPrivate: true,
 rentBall: false,
 totalPrice: 180,
 paymentMethod: 'wallet',
 status: BookingStatus.completed,
 createdByUserId: 'demo_user',
 createdAt: now.subtract(const Duration(days: 6)),
 ));
 }
}