import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../repositories/notification_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/booking_repository.dart';
import 'logger_service.dart';

/// Centralized factory for creating and sending notifications based on the VSP Notification Matrix.
class NotificationHandler {
  static NotificationRepository _notificationRepo = NotificationRepository();
  static final _userRepo = UserRepository();

  static set notificationRepo(NotificationRepository repo) {
    _notificationRepo = repo;
  }

  // --------------------------------------------------------------------------
  // 1. BOOKING FLOW
  // --------------------------------------------------------------------------

  /// Notify player that their booking is confirmed
  static Future<void> notifyBookingConfirmed({
    required String userId,
    required String stadiumName,
    required String bookingId,
    required String timeSlot,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'Booking Confirmed! ⚽',
      body: 'You booked $stadiumName at $timeSlot.',
      type: 'booking_confirmed',
      bookingId: bookingId,
      createdAt: DateTime.now(),
    );
    await _notificationRepo.sendNotification(userId, notif);
  }

  /// Notify owner that they have a new booking
  static Future<void> notifyNewBookingReceived({
    required String ownerId,
    required String stadiumName,
    required String playerName,
    required String bookingId,
    required String timeSlot,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'New Booking! 🏟️',
      body: '$playerName just booked $stadiumName at $timeSlot.',
      type: 'booking_new',
      bookingId: bookingId,
      createdAt: DateTime.now(),
    );
    await _notificationRepo.sendNotification(ownerId, notif);
  }

  /// Notify owner that a booking was cancelled
  static Future<void> notifyBookingCancelledByPlayer({
    required String ownerId,
    required String stadiumName,
    required String playerName,
    required String timeSlot,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'Booking Cancelled 🔴',
      body: '$playerName cancelled their booking for $stadiumName at $timeSlot.',
      type: 'booking_cancelled',
      createdAt: DateTime.now(),
    );
    await _notificationRepo.sendNotification(ownerId, notif);
  }

  /// Notify player that owner cancelled the booking
  static Future<void> notifyBookingCancelledByOwner({
    required String userId,
    required String stadiumName,
    required String timeSlot,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'Booking Cancelled 🔴',
      body: 'Your booking for $stadiumName at $timeSlot was cancelled by the stadium owner.',
      type: 'booking_cancelled',
      createdAt: DateTime.now(),
    );
    await _notificationRepo.sendNotification(userId, notif);
  }

  // --------------------------------------------------------------------------
  // 2. PUBLIC MATCH / FIND PLAYERS
  // --------------------------------------------------------------------------

  /// Notify host that a player joined their public match
  static Future<void> notifyPlayerJoinedMatch({
    required String hostId,
    required String playerName,
    required String stadiumName,
    required String bookingId,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'New Player Joined! ⚽',
      body: '$playerName joined your match at $stadiumName.',
      type: 'public_match_joined',
      bookingId: bookingId,
      createdAt: DateTime.now(),
    );
    await _notificationRepo.sendNotification(hostId, notif);
  }

  /// Special: Notify host that match is now full
  static Future<void> notifyMatchIsFull({
    required List<String> playerIds, // Includes host
    required String stadiumName,
    required String bookingId,
  }) async {
    for (final uid in playerIds) {
      final notif = AppNotification(
        id: '',
        title: 'Match is Full! 🔥',
        body: 'The match at $stadiumName is fully booked and ready to play!',
        type: 'match_full',
        bookingId: bookingId,
        createdAt: DateTime.now(),
      );
      await _notificationRepo.sendNotification(uid, notif);
    }
  }

  // --------------------------------------------------------------------------
  // 3. CHALLENGES
  // --------------------------------------------------------------------------

  /// Notify opponent team captain about a new challenge
  static Future<void> notifyChallengeReceived({
    required String opponentCaptainId,
    required String challengerTeamName,
    required String bookingId,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'New Challenge Request! 🏆',
      body: '$challengerTeamName has challenged your team to a match!',
      type: 'challenge',
      bookingId: bookingId,
      createdAt: DateTime.now(),
    );
    await _notificationRepo.sendNotification(opponentCaptainId, notif);
  }

  /// Notify challenger that their challenge was accepted
  static Future<void> notifyChallengeAccepted({
    required String challengerCaptainId,
    required String opponentTeamName,
    required String bookingId,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'Challenge Accepted! ✅',
      body: '$opponentTeamName accepted your challenge. Prepare for glory!',
      type: 'booking_confirmed',
      bookingId: bookingId,
      createdAt: DateTime.now(),
    );
    await _notificationRepo.sendNotification(challengerCaptainId, notif);
  }

  /// Notify challenger that their challenge was declined
  static Future<void> notifyChallengeDeclined({
    required String challengerCaptainId,
    required String opponentTeamName,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'Challenge Declined 🔴',
      body: '$opponentTeamName declined your challenge.',
      type: 'challenge_declined',
      createdAt: DateTime.now(),
    );
    await _notificationRepo.sendNotification(challengerCaptainId, notif);
  }

  // --------------------------------------------------------------------------
  // 4. OWNER & STADIUM
  // --------------------------------------------------------------------------

  /// Notify owner that their stadium is approved
  static Future<void> notifyStadiumApproved({
    required String ownerId,
    required String stadiumName,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'Stadium Approved! ✨',
      body: 'Congratulations! Your stadium "$stadiumName" has been verified and is now live.',
      type: 'stadium_approved',
      createdAt: DateTime.now(),
    );
    await _notificationRepo.sendNotification(ownerId, notif);
  }

  /// Notify owner that documents need attention
  static Future<void> notifyDocumentsNeeded({
    required String ownerId,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'Identity Verification Update ⚠️',
      body: 'Your documents need attention. Please re-upload them to complete your verification.',
      type: 'stadium_verification_needed',
      createdAt: DateTime.now(),
    );
    await _notificationRepo.sendNotification(ownerId, notif);
  }

  /// Notify participants about a new chat message
  static Future<void> notifyNewChatMessage({
    required List<String> recipientIds,
    required String senderName,
    required String messageText,
    required String bookingId,
  }) async {
    for (final uid in recipientIds) {
      final notif = AppNotification(
        id: '',
        title: 'New message from $senderName 💬',
        body: messageText,
        type: 'chat',
        bookingId: bookingId,
        createdAt: DateTime.now(),
      );
      await _notificationRepo.sendNotification(uid, notif);
    }
  }

  // --------------------------------------------------------------------------
  // 5. DEBT MANAGEMENT (Gentle Reminders Only — NO Auto-Blocking)
  // --------------------------------------------------------------------------

  /// Gentle reminder: Notify player about outstanding cash payment
  static Future<void> notifyDebtReminder({
    required String userId,
    required String stadiumName,
    required double amount,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'Payment Reminder 💰',
      body: 'You have a pending cash payment of ${amount.toStringAsFixed(0)} EGP for $stadiumName. Please settle it at the stadium at your earliest convenience.',
      type: 'debt_reminder',
      createdAt: DateTime.now(),
      metadata: {
        'amount': amount,
        'stadiumName': stadiumName,
      },
    );
    await _notificationRepo.sendNotification(userId, notif);
  }

  // --------------------------------------------------------------------------
  // 6. MATCH RESULT NOTIFICATION
  // --------------------------------------------------------------------------

  /// Notify team captain to submit match result after the game ends
  static Future<void> notifySubmitMatchResult({
    required String teamCaptainId,
    required String bookingId,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'Match Finished! ⚽',
      body: 'Please submit the final result to update your team\'s global ranking.',
      type: 'match_result_pending',
      bookingId: bookingId,
      createdAt: DateTime.now(),
    );
    await _notificationRepo.sendNotification(teamCaptainId, notif);
  }

  // --------------------------------------------------------------------------
  // 7. DEBT CHECKER (callable from a scheduled job or app start)
  // --------------------------------------------------------------------------

  /// Check all unpaid bookings and send gentle reminder notifications.
  /// NO blocking logic — only reminders.
  static Future<void> checkAndSendDebtAlerts(String userId) async {
    try {
      final unpaidBookings = await SupabaseBookingRepository().getUnpaidBookingsForUser(userId);

      for (final booking in unpaidBookings) {
        // Send a gentle reminder for any unpaid booking
        await notifyDebtReminder(
          userId: userId,
          stadiumName: booking.stadiumName,
          amount: booking.totalPrice,
        );
      }
    } catch (e) {
      VSPLogger.e('Error checking debt alerts', e);
    }
  }

  /// Handle reported player absence (No-Show) with automatic GPS dispute check.
  static Future<void> handleNoShowReport({
    required String bookingId,
    required String playerId,
    required double stadiumLat,
    required double stadiumLng,
  }) async {
    try {
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
        position ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        VSPLogger.w('Failed to get current position for no-show dispute: $e');
      }

      if (position == null) {
        await Supabase.instance.client.rpc('apply_no_show_penalty', params: {
          'p_player_id': playerId
        });
        VSPLogger.w('No-show penalty applied: GPS location could not be verified.');
        return;
      }
      
      // 2. Calculate geographic distance between player and stadium in meters
      final double distance = Geolocator.distanceBetween(
        position.latitude, position.longitude, stadiumLat, stadiumLng
      );

      // 3. If within 150m, dispute automatically and hold for admin moderation
      if (distance <= 150) {
        await Supabase.instance.client.from('bookings').update({
          'no_show_disputed': true,
          'notes': 'Disputed: Player was within ${distance.toStringAsFixed(0)}m of stadium.'
        }).eq('id', bookingId);
        VSPLogger.i('No-show disputed: Player was close to stadium.');
      } else {
        // Otherwise apply penalty via DB function
        await Supabase.instance.client.rpc('apply_no_show_penalty', params: {
          'p_player_id': playerId
        });
        VSPLogger.i('No-show penalty applied: Player was far from stadium (${distance.toStringAsFixed(0)}m).');
      }
    } catch (e) {
      VSPLogger.e('Error handling no show report with GPS check: $e');
    }
  }

  /// Notify joined players that the host cancelled the match
  static Future<void> notifyMatchCancelledByHost({
    required List<String> playerIds,
    required String stadiumName,
    required String timeSlot,
  }) async {
    for (final uid in playerIds) {
      final notif = AppNotification(
        id: '',
        title: 'Match Cancelled 🔴',
        body: 'The match at $stadiumName ($timeSlot) has been cancelled by the host.',
        type: 'booking_cancelled',
        createdAt: DateTime.now(),
      );
      await _notificationRepo.sendNotification(uid, notif);
    }
  }
}