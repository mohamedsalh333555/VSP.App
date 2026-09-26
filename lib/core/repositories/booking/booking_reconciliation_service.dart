import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../services/logger_service.dart';
import '../notification_repository.dart';
import '../team_repository.dart';
import '../user_repository.dart';
import 'booking_domain_rules.dart';

/// Handles match result submissions, ratings, and background reconciliation cron operations.
class BookingReconciliationService {
  final SupabaseClient? _client;
  final NotificationRepository? _notificationRepository;
  final UserRepository? _userRepository;
  final TeamRepository? _teamRepository;

  BookingReconciliationService({
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

  /// Submits match outcome and optional stadium rating review.
  Future<bool> submitMatchResult({
    required Booking booking,
    required String teamId,
    required MatchOutcome outcome,
    double? rating,
    String? review,
  }) async {
    try {
      if (BookingDomainRules.isResultSubmissionTimeLocked(booking.endTime, DateTime.now())) {
        throw Exception('Cannot submit results before the match officially ends.');
      }

      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('AUTH_REQUIRED');

      final result = booking.bookingType == BookingType.matchup
          ? await _supabase.rpc('record_matchup_result_atomic', params: {
              'p_booking_id': booking.id,
              'p_team_a_id': booking.playerTeamId,
              'p_team_b_id': booking.opponentTeamId,
              'p_outcome': switch (outcome) {
                MatchOutcome.homeWin => 'team_a_win',
                MatchOutcome.awayWin => 'team_b_win',
                MatchOutcome.draw => 'draw',
              },
            })
          : await _supabase.rpc('submit_challenge_result_atomic', params: {
              'p_booking_id': booking.id,
              'p_team_id': teamId,
              'p_outcome': outcome.name,
            });

      if (result is Map && result['success'] == false) {
        if (result['error'] == 'RESULT_DISPUTED') {
          if (rating != null && rating > 0) {
            await _submitRating(
              booking: booking,
              userId: user.id,
              rating: rating,
              review: review ?? '',
            );
          }
          return false;
        }
        throw Exception(result['error']?.toString() ?? 'RESULT_SUBMISSION_FAILED');
      }

      if (rating != null && rating > 0) {
        await _submitRating(
          booking: booking,
          userId: user.id,
          rating: rating,
          review: review ?? '',
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error submitting match result: $e');
      return false;
    }
  }

  Future<void> _submitRating({
    required Booking booking,
    required String userId,
    required double rating,
    required String review,
  }) async {
    final result = await _supabase.rpc('submit_stadium_review_atomic', params: {
      'p_stadium_id': booking.stadiumId,
      'p_user_id': userId,
      'p_user_name': _supabase.auth.currentUser?.userMetadata?['name']?.toString() ?? 'لاعب VSP',
      'p_user_image_url': _supabase.auth.currentUser?.userMetadata?['avatar_url']?.toString() ?? '',
      'p_rating': rating.toInt(),
      'p_comment': review,
    });
    if (result is Map && result['success'] == false) {
      throw Exception(result['error']?.toString() ?? 'REVIEW_SUBMISSION_FAILED');
    }
  }

  /// Automatically marks past confirmed bookings as completed via server RPC.
  Future<void> autoReconcilePastBookings() async {
    try {
      await _supabase.rpc('auto_reconcile_past_bookings');
      VSPLogger.i('auto_reconcile_past_bookings RPC executed successfully');
    } catch (e) {
      VSPLogger.e('Error in autoReconcilePastBookings RPC', e);
    }
  }

  /// Automatically cancels pending challenges when expiration deadline is met.
  Future<void> autoExpirePendingChallenges() async {
    // Expiration is server-scheduled by the platform cron; client sessions
    // must never mutate unrelated users' bookings.
    return;
  }

  /// Auto-reconciles matches where only one captain entered results and 24h have passed.
  Future<void> autoReconcileSingleEntryResults() async {
    // Global reconciliation runs from the trusted server scheduler.
    return;
  }


  /// Sends reminder notification to submit match result 1 hour post-match.
  Future<void> autoNudgePostMatchResults() async {
    // Post-match nudges are emitted by the trusted server scheduler.
    return;
  }
}
