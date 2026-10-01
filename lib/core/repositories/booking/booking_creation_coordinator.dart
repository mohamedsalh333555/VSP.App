import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../services/analytics_service.dart';
import '../../services/logger_service.dart';
import '../notification_repository.dart';
import '../team_repository.dart';
import '../user_repository.dart';

/// Coordinates atomic booking creation via RPC, notifications to owner/opponent, and analytics.
class BookingCreationCoordinator {
  final SupabaseClient? _client;
  final NotificationRepository? _notificationRepository;
  final TeamRepository? _teamRepository;

  BookingCreationCoordinator({
    SupabaseClient? client,
    NotificationRepository? notificationRepository,
    UserRepository? userRepository,
    TeamRepository? teamRepository,
  })  : _client = client,
        _notificationRepository = notificationRepository,
        _teamRepository = teamRepository;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  NotificationRepository get _notificationRepo => _notificationRepository ?? NotificationRepository();
  TeamRepository get _teamRepo => _teamRepository ?? TeamRepository();

  /// Converts domain [BookingType] to canonical database string (SSOT: personal | open_join | challenge).
  static String dbBookingType(BookingType type) {
    switch (type) {
      case BookingType.openJoin:
        return 'open_join';
      case BookingType.challenge:
        return 'challenge';
      case BookingType.team:
      case BookingType.matchup:
      case BookingType.personal:
        return 'personal';
    }
  }

  /// Creates a booking atomically in Supabase using create_booking_atomic RPC.
  Future<Booking> createBooking({
    required BookingDraft draft,
    required String userId,
    required Future<Booking?> Function(String) getBookingById,
  }) async {
    try {
      // The server calculates payment fees from the authoritative payment transaction.
      const double platformFee = 0.0;
      final dynamic rpcResult;
      if (draft.bookingType == BookingType.challenge &&
          draft.challengeCode != null &&
          draft.challengeCode!.trim().isNotEmpty) {
        rpcResult = await _supabase.rpc('create_challenge_booking_atomic', params: {
          'p_challenge_code': draft.challengeCode!.trim(),
          'p_stadium_id': draft.stadiumId,
          'p_start_time': draft.startTime.toUtc().toIso8601String(),
          'p_end_time': draft.endTime.toUtc().toIso8601String(),
          'p_payment_method': draft.paymentMethod ?? 'cash',
          'p_rent_ball': draft.rentBall,
        });
      } else {
        rpcResult = await _supabase.rpc('create_booking_atomic', params: {
          'p_stadium_id': draft.stadiumId,
          'p_user_id': userId,
          'p_owner_id': draft.ownerId,
          'p_start_time': draft.startTime.toUtc().toIso8601String(),
          'p_end_time': draft.endTime.toUtc().toIso8601String(),
          'p_booking_type': dbBookingType(draft.bookingType),
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
          // Server persists the host's real player count for open_join
          'p_initial_players': (draft.bookingType == BookingType.openJoin)
              ? draft.currentPlayers
              : 1,

          'p_total_capacity': draft.totalFieldCapacity,
        });
      }

      if (rpcResult is Map && rpcResult['success'] == false) {
        final err = rpcResult['error']?.toString() ?? '';
        if (err == 'CHALLENGE_CODE_INVALID_OR_USED') {
          throw Exception('كود التحدي غير صالح أو تم استخدامه من قبل.');
        } else if (err == 'CALLER_NOT_A_CAPTAIN') {
          throw Exception('يجب أن تكون كابتن فريق لتأكيد حجز التحدي.');
        } else if (err == 'CANNOT_CHALLENGE_OWN_TEAM') {
          throw Exception('لا يمكن تحدي فريقك نفسه.');
        } else if (err == 'OPPONENT_TEAM_NOT_FOUND') {
          throw Exception('تعذر العثور على الفريق المنافس.');
        } else if (err == 'SLOT_LOCKED_OR_TAKEN') {
          throw Exception('عذراً، هذا الموعد محجوز لمباراة أخرى.');
        }

        String errorMessage = rpcResult['message']?.toString() ??
            rpcResult['error']?.toString() ??
            'عذراً، هذا التوقيت محجوز بالفعل لمباراة أخرى.';
        final errorCode = rpcResult['code']?.toString() ?? err;

        if (errorMessage.contains('???')) {
          if (errorCode == 'SLOT_LOCKED_OR_TAKEN') {
            errorMessage = 'عذراً، هذا الموعد محجوز أو قيد الدفع من قِبل لاعب آخر حالياً.';
          } else if (errorMessage.contains('????? ???? ?? ????? ??????')) {
            errorMessage = 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.';
          } else if (errorMessage.contains('???? ??? ???? ??? ??????')) {
            errorMessage = 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.';
          } else if (errorMessage.contains('????? ???? ??????')) {
            errorMessage = 'حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.';
          } else {
            errorMessage = 'عذراً، تعذر إتمام الحجز. يرجى التأكد من الموعد والمحاولة لاحقاً.';
          }
        }

        throw Exception(errorMessage);
      }

      final bookingId = (rpcResult is Map) ? rpcResult['booking_id']?.toString() : null;
      if (bookingId == null) {
        throw Exception('فشل تسجيل الحجز في قاعدة البيانات.');
      }

      final created = await getBookingById(bookingId);
      if (created == null) throw Exception('تعذر جلب تفاصيل الحجز بعد الإنشاء.');

      // Only notify owner when booking is actually confirmed (cash = immediate confirm; online = wait for webhook)
      if (created.status == BookingStatus.confirmed || draft.paymentMethod == 'cash') {
        sendOwnerNotification(draft, created.id);
        // For challenge: also notify opponent team captain — only after confirmation
        // NOTE: challenge bookings via create_challenge_booking_atomic handle this separately
        // This path only fires for legacy challenge flow or cash challenges
        if (draft.bookingType == BookingType.challenge && draft.opponentTeamId != null) {
          sendChallengeConfirmedNotification(draft, created.id);
        }
      }
      // For online challenge bookings: notification is sent by the webhook after payment succeeds
      // Do NOT send 'Challenge Confirmed' here for pending online payments

      AnalyticsService.logStadiumBooked(draft.stadiumId, draft.totalPrice);
      VSPLogger.i('Atomic booking created: ${created.id}');
      return created;
    } on PostgrestException catch (e) {
      if (e.code == '23P11' || e.message.contains('overlapping') || e.message.contains('exclude') || e.code == '23505') {
        throw Exception('عذراً، هذا التوقيت محجوز بالفعل لمباراة أخرى.');
      }
      rethrow;
    } catch (e) {
      VSPLogger.e('Error creating booking', e);
      rethrow;
    }
  }

  /// Sends booking notification to stadium owner.
  Future<void> sendOwnerNotification(BookingDraft draft, String bookingId) async {
    try {
      final dateStr = DateFormat('MMM d', 'en').format(draft.startTime);
      final timeStr = DateFormat('h:mm a', 'en').format(draft.startTime);
      await _notificationRepo.sendNotification(
        draft.ownerId,
        AppNotification(
          id: '',
          title: 'New Booking Received!',
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

  /// Sends challenge CONFIRMED notification to opponent captain.
  /// Only called AFTER booking is actually confirmed (cash or post-payment webhook).
  Future<void> sendChallengeConfirmedNotification(BookingDraft draft, String bookingId) async {
    try {
      if (draft.opponentTeamId == null) return;
      final team = await _teamRepo.getTeam(draft.opponentTeamId!);
      if (team == null) return;

      final captainId = team.captainId;
      if (captainId.isEmpty) return;

      final dateStr = DateFormat('d MMM', 'ar').format(draft.startTime);
      await _notificationRepo.sendNotification(
        captainId,
        AppNotification(
          id: '',
          title: 'تم تأكيد مباراة تحدي!',
          body: '${draft.playerTeamName ?? "فريق"} × ${draft.opponentTeamName ?? "فريقك"} في ${draft.stadiumName} — $dateStr.',
          type: 'challenge_confirmed',
          bookingId: bookingId,
          createdAt: DateTime.now(),
        ),
      );
      AnalyticsService.logChallengeSent(draft.playerTeamId ?? 'unknown', draft.opponentTeamId!);
    } catch (e) {
      VSPLogger.e('Error sending challenge confirmed notification', e);
    }
  }
}
