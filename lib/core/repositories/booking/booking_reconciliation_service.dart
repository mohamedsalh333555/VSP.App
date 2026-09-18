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
        VSPLogger.w('Result submission blocked: Match has not ended yet for booking ${booking.id}');
        throw Exception('Cannot submit results before the match officially ends.');
      }

      final currentMatchStatus = booking.matchResultStatus;
      final submittedBy = booking.resultSubmittedByTeamId;

      Future<void> saveRating() async {
        if (rating != null && rating > 0) {
          final effectiveUserId = _supabase.auth.currentUser?.id ?? booking.createdByUserId;

          final existing = await _supabase
              .from('reviews')
              .select('id')
              .eq('stadium_id', booking.stadiumId)
              .eq('user_id', effectiveUserId)
              .maybeSingle();

          if (existing != null) {
            VSPLogger.i('Skipping duplicate review submission for booking ${booking.id}');
            return;
          }

          String userName = 'لاعب VSP';
          String userImageUrl = '';
          try {
            final userDoc = await _userRepo.getUserData(effectiveUserId);
            if (userDoc != null) {
              userName = userDoc['name'] ?? userName;
              userImageUrl = userDoc['profile_image_url'] ?? '';
            }
          } catch (_) {}

          await _supabase.from('reviews').insert({
            'stadium_id': booking.stadiumId,
            'user_id': effectiveUserId,
            'user_name': userName,
            'user_image_url': userImageUrl,
            'rating': rating.toInt(),
            'review_text': review ?? '',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });

          VSPLogger.i('Stadium review inserted. DB Trigger will update rating average.');
        }
      }

      // Case A: First submission (no result yet) OR Captain 1 editing their submitted result
      if (currentMatchStatus == MatchResultStatus.noResult || submittedBy == teamId) {
        await _supabase.from('bookings').update({
          'pending_outcome': outcome.name,
          'result_submitted_by_team_id': teamId,
          'match_result_status': MatchResultStatus.waitingOpponent.name,
          'requires_admin_intervention': false,
          'final_outcome': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', booking.id);
        await saveRating();
        return true;
      }
      // Case B: Captain 2 responding
      else if (submittedBy != teamId) {
        final pendingOutcomeStr = booking.pendingOutcome?.name;

        if (pendingOutcomeStr == outcome.name) {
          await _supabase.from('bookings').update({
            'final_outcome': outcome.name,
            'match_result_status': MatchResultStatus.confirmed.name,
            'status': BookingStatus.completed.name,
            'requires_admin_intervention': false,
            'pending_outcome': null,
            'result_submitted_by_team_id': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', booking.id);

          await saveRating();
          return true;
        } else {
          await _supabase.from('bookings').update({
            'match_result_status': MatchResultStatus.disputed.name,
            'requires_admin_intervention': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', booking.id);
          await saveRating();
          return false;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error submitting match result: $e');
      return false;
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

        final shouldExpire = BookingDomainRules.shouldChallengeExpire(
          createdAt: createdAt,
          startTime: startTime,
          now: now,
        );

        if (shouldExpire) {
          await _supabase.from('bookings').update({
            'status': BookingStatus.cancelled.name,
            'updated_at': now.toUtc().toIso8601String(),
          }).eq('id', booking.id);

          await _notificationRepo.sendNotification(
            booking.createdByUserId,
            AppNotification(
              id: '',
              title: 'إلغاء التحدي تلقائياً / Challenge Expired',
              body: 'انتهت مهلة التحدي لعدم رد الخصم، تم إلغاء الحجز تلقائياً لتتمكن من تحدي فريق آخر',
              type: 'info',
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      VSPLogger.e('Error in autoExpirePendingChallenges', e);
    }
  }

  /// Auto-reconciles matches where only one captain entered results and 24h have passed.
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

        if (now.difference(updatedAt).inHours >= 24) {
          final outcome = booking.pendingOutcome ?? MatchOutcome.draw;
          final homeTeamId = booking.playerTeamId;
          final awayTeamId = booking.opponentTeamId;

          if (homeTeamId != null && awayTeamId != null) {
            await _teamRepo.updateMatchResult(
              booking.id,
              homeTeamId,
              awayTeamId,
              outcome,
            );

            final submittedBy = booking.resultSubmittedByTeamId;
            final nonRespondingTeamId = (submittedBy == homeTeamId) ? awayTeamId : homeTeamId;

            final teamDoc = await _supabase
                .from('teams')
                .select('attendance_score')
                .eq('id', nonRespondingTeamId)
                .maybeSingle();

            if (teamDoc != null) {
              final currentAttendance = (teamDoc['attendance_score'] as num?)?.toInt() ?? 100;
              final newAttendance = (currentAttendance - 5).clamp(0, 100);

              await _supabase
                  .from('teams')
                  .update({'attendance_score': newAttendance})
                  .eq('id', nonRespondingTeamId);

              VSPLogger.i('Attendance Penalty Applied: Team $nonRespondingTeamId penalized to $newAttendance%');
            }
          }

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

  /// Sends reminder notification to submit match result 1 hour post-match.
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
          await _notificationRepo.sendNotification(
            booking.createdByUserId,
            AppNotification(
              id: '',
              title: 'تسجيل نتيجة المباراة / Submit Match Result',
              body: 'انتهت المباراة! يرجى تسجيل النتيجة لضمان تحديث نقاط فريقك وسجل المباريات.',
              type: 'action_required',
              createdAt: DateTime.now(),
              bookingId: booking.id,
            ),
          );

          await _supabase.from('bookings').update({
            'notes': notes.isEmpty ? '[NUDGED]' : '$notes [NUDGED]',
            'updated_at': now.toUtc().toIso8601String(),
          }).eq('id', booking.id);
        }
      }
    } catch (e) {
      VSPLogger.e('Error in autoNudgePostMatchResults', e);
    }
  }
}
