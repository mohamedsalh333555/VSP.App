import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safe_device/safe_device.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../repositories/notification_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/booking_repository.dart';
import '../utils/vsp_feedback.dart';
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
        metadata: {
          'priority': 'high',
          'content_available': true,
          'sound': 'default',
          'android_channel_id': 'vsp_p2p_alerts',
          'vibration_pattern': [0, 500, 200, 500],
        },
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

  /// Handle reported player absence (No-Show)
  static Future<void> handleNoShowReport(
    String bookingId,
    String playerId,
    double stadiumLat,
    double stadiumLng,
  ) async {
    try {
      // 1. Call Supabase RPC 'apply_no_show_penalty' to increment the player's no-show count
      await Supabase.instance.client.rpc('apply_no_show_penalty', params: {
        'p_player_id': playerId,
      });

      // 2. Send an interactive FCM push notification to the player
      final notif = AppNotification(
        id: '',
        title: 'No-Show Warning! ⚠️',
        body: 'You were reported absent. Open the app to Dispute using GPS.',
        type: 'no_show_warning',
        bookingId: bookingId,
        createdAt: DateTime.now(),
        metadata: {
          'stadiumLat': stadiumLat,
          'stadiumLng': stadiumLng,
          'playerId': playerId,
        },
      );
      await _notificationRepo.sendNotification(playerId, notif);
      VSPLogger.i('No-show penalty applied and notification sent to player $playerId.');
    } catch (e) {
      VSPLogger.e('Error applying no-show report: $e');
    }
  }

  /// Dispute a no-show report on player's device using GPS location and SafeDevice spoofing checks
  static Future<bool> disputeNoShowWithGPS({
    required String bookingId,
    required String playerId,
    required double stadiumLat,
    required double stadiumLng,
  }) async {
    try {
      // 1. Security Check: SafeDevice checks
      try {
        final bool isJailBroken = await SafeDevice.isJailBroken.timeout(
          const Duration(seconds: 2),
          onTimeout: () => true,
        );
        final bool isMockLocation = await SafeDevice.isMockLocation.timeout(
          const Duration(seconds: 2),
          onTimeout: () => true,
        );
        if (isJailBroken || isMockLocation) {
          VSPLogger.w("⚠️ Device Security Alert: Jailbroken=$isJailBroken, MockLocation=$isMockLocation");
          final context = navigatorKey.currentContext;
          if (context != null) {
            VSPFeedback.showError(context, 'فشل التحقق: تم كشف التلاعب بالموقع الجغرافي! ⚠️');
          }
          return false;
        }
      } catch (e) {
        VSPLogger.e("Error performing safe device checks: $e");
        final context = navigatorKey.currentContext;
        if (context != null) {
          VSPFeedback.showError(context, 'فشل التحقق بسبب خطأ أمني! ⚠️');
        }
        return false;
      }

      // 2. Fetch player's current location using Geolocator
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            VSPFeedback.showError(context, 'يرجى إعطاء صلاحية الموقع الجغرافي لتقديم النزاع. 📍');
          }
          return false;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          VSPFeedback.showError(context, 'صلاحية الموقع الجغرافي معطلة تماماً. يرجى تفعيلها من الإعدادات. ⚙️');
        }
        return false;
      }

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
        final context = navigatorKey.currentContext;
        if (context != null) {
          VSPFeedback.showError(context, 'تعذر تحديد موقعك الحالي. يرجى التحقق من اتصال الـ GPS. 📡');
        }
        return false;
      }

      // 🛡️ SECURITY BARRIER: GPS Accuracy Gate
      // Reject disputes when GPS signal accuracy is worse than 30 meters.
      // This prevents spoofed/indoor/WiFi-only low-accuracy GPS from falsely
      // passing the proximity check. Players must be in an open area with a
      // strong satellite lock.
      if (position.accuracy > 30) {
        VSPLogger.w('GPS dispute rejected: Accuracy too low (${position.accuracy.toStringAsFixed(1)}m > 30m threshold)');
        final context = navigatorKey.currentContext;
        if (context != null) {
          VSPFeedback.showError(
            context,
            'فشل التحقق! دقة إشارة الـ GPS ضعيفة جداً (${position.accuracy.toStringAsFixed(0)} متر). '
            'يجب أن تكون الدقة أقل من 30 متراً. يرجى الانتقال لمنطقة مفتوحة وإعادة المحاولة. 📡',
          );
        }
        return false;
      }

      // 3. Invoke the secured Supabase RPC dispute function
      try {
        final bool success = await Supabase.instance.client.rpc('dispute_no_show_with_gps', params: {
          'p_booking_id': bookingId,
          'p_player_id': playerId,
          'p_lat': position.latitude,
          'p_lng': position.longitude,
          'p_accuracy': position.accuracy,
        });

        if (success) {
          VSPLogger.i('No-show penalty successfully dismissed via GPS database verification.');
          final context = navigatorKey.currentContext;
          if (context != null) {
            VSPFeedback.triggerSuccess();
            const msgAr = 'تم قبول النزاع وإلغاء العقوبة بنجاح! 🏆';
            VSPFeedback.showSuccess(context, msgAr);
          }
          return true;
        } else {
          final context = navigatorKey.currentContext;
          if (context != null) {
            const msgAr = 'فشل النزاع: لم يتم التحقق من موقعك.';
            VSPFeedback.showError(context, msgAr);
          }
          return false;
        }
      } on PostgrestException catch (e) {
        VSPLogger.e('Database error during GPS dispute: ${e.message}');
        final context = navigatorKey.currentContext;
        if (context != null) {
          final String errorMsg = e.message.toLowerCase();
          if (errorMsg.contains('dispute_window_expired')) {
            VSPFeedback.showError(
              context,
              'عذراً، انتهت المهلة الزمنية لتقديم النزاع! ⚠️ كان يجب تقديم النزاع خلال ساعة واحدة كحد أقصى من نهاية وقت المباراة.',
            );
          } else if (errorMsg.contains('not_at_stadium')) {
            VSPFeedback.showError(
              context,
              'فشل النزاع: أنت لست متواجداً في محيط الملعب حالياً! 📍 يرجى تفعيل الـ GPS والتواجد في أرضية الملعب للمحاولة.',
            );
          } else if (errorMsg.contains('booking_not_found')) {
            VSPFeedback.showError(
              context,
              'هذا الحجز غير مسجل في النظام.',
            );
          } else {
            VSPFeedback.showError(context, e.message);
          }
        }
        return false;
      } catch (e) {
        VSPLogger.e('Unexpected error during GPS dispute: $e');
        final context = navigatorKey.currentContext;
        if (context != null) {
          VSPFeedback.showError(context, e.toString());
        }
        return false;
      }
    } catch (e) {
      VSPLogger.e('Error disputing no-show with GPS: $e');
      return false;
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

  static Future<bool> disputeWithGeotaggedSelfie({required String bookingId, required String playerId, required String photoUrl, required double imageLat, required double imageLng, required DateTime imageTimestamp, required double stadiumLat, required double stadiumLng}) async { try { final booking = await SupabaseBookingRepository().getBookingById(bookingId); if (booking == null) return false; final diff = imageTimestamp.difference(booking.endTime).inMinutes; if (diff > 60) return false; final dLat = (imageLat - stadiumLat).abs() * 111000; final dLng = (imageLng - stadiumLng).abs() * 111000; if (dLat + dLng > 150.0) return false; await Supabase.instance.client.from('users').update({'no_show_count': 0, 'cash_booking_banned': false}).eq('id', playerId); await Supabase.instance.client.from('bookings').update({'is_dispute_approved': true, 'dispute_photo_url': photoUrl}).eq('id', bookingId); return true; } catch (e) { return false; } }
}