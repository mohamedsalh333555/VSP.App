import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../services/analytics_service.dart';
import '../../services/logger_service.dart';
import '../notification_repository.dart';
import '../team_repository.dart';

/// Coordinates atomic booking creation via RPC, notifications to owner/opponent, and analytics.
class BookingCreationCoordinator {
  final SupabaseClient? _client;
  final NotificationRepository? _notificationRepository;
  final UserRepository? _userRepository;
  final TeamRepository? _teamRepository;

  BookingCreationCoordinator({
    SupabaseClient? client,
    NotificationRepository? notificationRepository,
    UserRepository? userRepository,
    TeamRepository? teamRepository,
  })  : _client = client,
        _notificationRepository = notificationRepository,
        _userRepository = userRepository,
        _teamRepository = teamRepository;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  NotificationRepository get _notificationRepo => _notificationRepository ?? NotificationRepository();
  UserRepository get _userRepo => _userRepository ?? UserRepository();
  TeamRepository get _teamRepo => _teamRepository ?? TeamRepository();

  /// Converts domain [BookingType] to database string representation.
  static String dbBookingType(BookingType type) {
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

  /// Creates a booking atomically in Supabase using create_booking_atomic RPC.
  Future<Booking> createBooking({
    required BookingDraft draft,
    required String userId,
    required Future<Booking?> Function(String) getBookingById,
  }) async {
    try {
      // The server calculates payment fees from the authoritative payment transaction.
      const double platformFee = 0.0;
      final rpcResult = await _supabase.rpc('create_booking_atomic', params: {
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
      });

      if (rpcResult is Map && rpcResult['success'] == false) {
        String errorMessage = rpcResult['message']?.toString() ?? 'عذراً، هذا التوقيت محجوز بالفعل لمباراة أخرى.';
        final errorCode = rpcResult['code']?.toString();

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

      if (draft.bookingType == BookingType.challenge && draft.opponentTeamId != null) {
        sendChallengeNotification(draft);
      }
      if (created.status == BookingStatus.confirmed || draft.paymentMethod == 'cash') {
        sendOwnerNotification(draft, created.id);
      }

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

  /// Sends challenge notification to opponent team captain.
  Future<void> sendChallengeNotification(BookingDraft draft) async {
    try {
      if (draft.opponentTeamId == null) return;
      final team = await _teamRepo.getTeam(draft.opponentTeamId!);
      if (team == null) return;

      final captainId = team.captainId;
      if (captainId.isEmpty) return;

      await _notificationRepo.sendNotification(
        captainId,
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
}
