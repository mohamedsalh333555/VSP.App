import '../../data/models.dart';
import '../repositories/booking_repository.dart';
import '../repositories/notification_repository.dart';
import 'logger_service.dart';
import 'no_show_dispute_service.dart';

/// Centralized factory for creating and sending notifications based on the VSP Notification Matrix.
class NotificationHandler {
  static NotificationRepository _notificationRepo = NotificationRepository();

  static set notificationRepo(NotificationRepository repo) {
    _notificationRepo = repo;
    NoShowDisputeService.notificationRepo = repo;
  }

  static Map<String, dynamic> _localizedCopy({
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    Map<String, dynamic>? metadata,
  }) {
    return {
      ...?metadata,
      'title_ar': titleAr,
      'title_en': titleEn,
      'body_ar': bodyAr,
      'body_en': bodyEn,
    };
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
      title: 'Booking Confirmed! ',
      body: 'You booked $stadiumName at $timeSlot.',
      type: 'booking_confirmed',
      bookingId: bookingId,
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'تم تأكيد الحجز',
        titleEn: 'Booking confirmed',
        bodyAr: 'تم حجز $stadiumName في $timeSlot.',
        bodyEn: 'You booked $stadiumName at $timeSlot.',
      ),
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
      title: 'New Booking! ',
      body: '$playerName just booked $stadiumName at $timeSlot.',
      type: 'booking_new',
      bookingId: bookingId,
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'حجز جديد',
        titleEn: 'New booking',
        bodyAr: 'قام $playerName بحجز $stadiumName في $timeSlot.',
        bodyEn: '$playerName just booked $stadiumName at $timeSlot.',
      ),
    );
    await _notificationRepo.sendNotification(ownerId, notif);
  }

  /// Notify owner that a booking was cancelled
  static Future<void> notifyBookingCancelledByPlayer({
    required String ownerId,
    required String stadiumName,
    required String playerName,
    required String timeSlot,
    required String bookingId,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'Booking Cancelled ',
      body: '$playerName cancelled their booking for $stadiumName at $timeSlot.',
      type: 'booking_cancelled',
      bookingId: bookingId,
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'تم إلغاء الحجز',
        titleEn: 'Booking cancelled',
        bodyAr: 'قام $playerName بإلغاء حجزه في $stadiumName عند $timeSlot.',
        bodyEn: '$playerName cancelled their booking for $stadiumName at $timeSlot.',
      ),
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
      title: 'Booking Cancelled ',
      body: 'Your booking for $stadiumName at $timeSlot was cancelled by the stadium owner.',
      type: 'booking_cancelled',
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'تم إلغاء الحجز',
        titleEn: 'Booking cancelled',
        bodyAr: 'ألغى مسؤول الملعب حجزك في $stadiumName عند $timeSlot.',
        bodyEn: 'Your booking for $stadiumName at $timeSlot was cancelled by the stadium owner.',
      ),
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
      title: 'New Player Joined! ',
      body: '$playerName joined your match at $stadiumName.',
      type: 'public_match_joined',
      bookingId: bookingId,
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'انضم لاعب جديد',
        titleEn: 'A player joined',
        bodyAr: 'انضم $playerName إلى مباراتك في $stadiumName.',
        bodyEn: '$playerName joined your match at $stadiumName.',
      ),
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
        title: 'Match is Full! ',
        body: 'The match at $stadiumName is fully booked and ready to play!',
        type: 'match_full',
        bookingId: bookingId,
        createdAt: DateTime.now(),
        metadata: _localizedCopy(
          titleAr: 'اكتمل عدد اللاعبين',
          titleEn: 'Match is full',
          bodyAr: 'اكتمل عدد لاعبي المباراة في $stadiumName وأصبحت جاهزة للعب.',
          bodyEn: 'The match at $stadiumName is fully booked and ready to play!',
        ),
      );
      await _notificationRepo.sendNotification(uid, notif);
    }
  }

  /// Notify player that their open join request was declined by host
  static Future<void> notifyJoinRequestRejected({
    required String playerId,
    required String stadiumName,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'Join Request Declined',
      body: 'Your request to join the match at $stadiumName was declined.',
      type: 'join_request_declined',
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'تم رفض طلب الانضمام',
        titleEn: 'Join request declined',
        bodyAr: 'تم رفض طلبك للانضمام إلى المباراة في $stadiumName.',
        bodyEn: 'Your request to join the match at $stadiumName was declined.',
      ),
    );
    await _notificationRepo.sendNotification(playerId, notif);
  }

  // --------------------------------------------------------------------------
  // 3. CHALLENGES (Code-driven instant confirmation SSOT)
  // --------------------------------------------------------------------------

  /// Notify opponent team captain that a challenge match has been confirmed
  static Future<void> notifyChallengeConfirmed({
    required String opponentCaptainId,
    required String challengerTeamName,
    required String stadiumName,
    required String bookingId,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'مباراة تحدي جديدة! ⚔️',
      body: 'تم تثبيت مباراة تحدي بين فريقك وفريق $challengerTeamName في ملعب $stadiumName!',
      type: 'challenge_confirmed',
      bookingId: bookingId,
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'مباراة تحدي جديدة! ⚔️',
        titleEn: 'New challenge match! ⚔️',
        bodyAr: 'تم تثبيت مباراة تحدي بين فريقك وفريق $challengerTeamName في ملعب $stadiumName!',
        bodyEn: 'A challenge match between your team and $challengerTeamName is confirmed at $stadiumName!',
      ),
    );
    await _notificationRepo.sendNotification(opponentCaptainId, notif);
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
      title: 'Stadium Approved! ',
      body: 'Congratulations! Your stadium "$stadiumName" has been verified and is now live.',
      type: 'stadium_approved',
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'تم اعتماد الملعب',
        titleEn: 'Stadium approved',
        bodyAr: 'مبروك! تم التحقق من ملعبك وأصبح متاحاً للاعبين.',
        bodyEn: 'Congratulations! Your stadium "$stadiumName" has been verified and is now live.',
      ),
    );
    await _notificationRepo.sendNotification(ownerId, notif);
  }

  /// Notify owner that documents need attention
  static Future<void> notifyDocumentsNeeded({
    required String ownerId,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'Identity Verification Update ',
      body: 'Your documents need attention. Please re-upload them to complete your verification.',
      type: 'stadium_verification_needed',
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'تحديث مستندات التحقق',
        titleEn: 'Verification documents need attention',
        bodyAr: 'تحتاج مستنداتك إلى مراجعة. أعد رفعها لاستكمال التحقق.',
        bodyEn: 'Your documents need attention. Please re-upload them to complete your verification.',
      ),
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
        title: 'رسالة جديدة من $senderName ',
        body: messageText,
        type: 'chat',
        bookingId: bookingId,
        createdAt: DateTime.now(),
        metadata: _localizedCopy(
          titleAr: 'رسالة جديدة من $senderName',
          titleEn: 'New message from $senderName',
          bodyAr: messageText,
          bodyEn: messageText,
          metadata: {
          'priority': 'high',
          'content_available': true,
          'sound': 'default',
          'android_channel_id': 'vsp_p2p_alerts',
          'vibration_pattern': [0, 500, 200, 500],
          },
        ),
      );
      await _notificationRepo.sendNotification(uid, notif);
    }
  }

  /// Notify tournament owner when a team joins their tournament
  static Future<void> notifyTeamJoinedTournament({
    required String ownerId,
    required String teamName,
    required String tournamentName,
    required String championshipId,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'فريق جديد انضم لبطولتك! ',
      body: 'انضم فريق "$teamName" إلى بطولة "$tournamentName".',
      type: 'tournament_joined',
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'انضم فريق جديد إلى بطولتك',
        titleEn: 'A new team joined your tournament',
        bodyAr: 'انضم فريق "$teamName" إلى بطولة "$tournamentName".',
        bodyEn: 'Team "$teamName" joined "$tournamentName".',
        metadata: {
        'championship_id': championshipId,
        'team_name': teamName,
        'tournament_name': tournamentName,
        'sound': 'default',
        },
      ),
    );
    await _notificationRepo.sendNotification(ownerId, notif);
  }

  /// Notify user/owner when a payment or deposit is received
  static Future<void> notifyPaymentReceived({
    required String recipientId,
    required String userName,
    required double amount,
    required String bookingId,
  }) async {
    final notif = AppNotification(
      id: '',
      title: 'تم استلام دفعة مالية ',
      body: 'تم استلام مبلغ ${amount.toStringAsFixed(0)} ج.م من $userName.',
      type: 'payment_received',
      bookingId: bookingId,
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'تم استلام دفعة مالية',
        titleEn: 'Payment received',
        bodyAr: 'تم استلام مبلغ ${amount.toStringAsFixed(0)} ج.م من $userName.',
        bodyEn: 'A payment of ${amount.toStringAsFixed(0)} EGP was received from $userName.',
        metadata: {
          'amount': amount,
          'userName': userName,
          'bookingId': bookingId,
          'sound': 'default',
        },
      ),
    );
    await _notificationRepo.sendNotification(recipientId, notif);
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
      title: 'Payment Reminder ',
      body: 'You have a pending cash payment of ${amount.toStringAsFixed(0)} EGP for $stadiumName. Please settle it at the stadium at your earliest convenience.',
      type: 'debt_reminder',
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'تذكير بسداد المستحقات',
        titleEn: 'Payment reminder',
        bodyAr: 'لديك مبلغ نقدي مستحق بقيمة ${amount.toStringAsFixed(0)} ج.م لصالح $stadiumName. يرجى سداده في الملعب.',
        bodyEn: 'You have a pending cash payment of ${amount.toStringAsFixed(0)} EGP for $stadiumName. Please settle it at the stadium.',
        metadata: {
          'amount': amount,
          'stadiumName': stadiumName,
        },
      ),
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
      title: 'Match Finished! ',
      body: 'Please submit the final result to update your team\'s global ranking.',
      type: 'match_result_pending',
      bookingId: bookingId,
      createdAt: DateTime.now(),
      metadata: _localizedCopy(
        titleAr: 'انتهت المباراة',
        titleEn: 'Match finished',
        bodyAr: 'سجّل النتيجة النهائية لتحديث ترتيب فريقك.',
        bodyEn: 'Please submit the final result to update your team\'s global ranking.',
      ),
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

  /// Notify joined players that the host cancelled the match
  static Future<void> notifyMatchCancelledByHost({
    required List<String> playerIds,
    required String stadiumName,
    required String timeSlot,
    required String bookingId,
  }) async {
    for (final uid in playerIds) {
      final notif = AppNotification(
        id: '',
        title: 'Match Cancelled ',
        body: 'The match at $stadiumName ($timeSlot) has been cancelled by the host.',
        type: 'booking_cancelled',
        bookingId: bookingId,
        createdAt: DateTime.now(),
        metadata: _localizedCopy(
          titleAr: 'تم إلغاء المباراة',
          titleEn: 'Match cancelled',
          bodyAr: 'تم إلغاء المباراة في $stadiumName عند $timeSlot بواسطة المنظم.',
          bodyEn: 'The match at $stadiumName ($timeSlot) has been cancelled by the host.',
        ),
      );
      await _notificationRepo.sendNotification(uid, notif);
    }
  }

  // --------------------------------------------------------------------------
  // 8. NO-SHOW & DISPUTE DELEGATIONS
  // --------------------------------------------------------------------------

  /// Forwarder to NoShowDisputeService for backward compatibility.
  static Future<void> handleNoShowReport(
    String bookingId,
    String playerId,
    double stadiumLat,
    double stadiumLng,
  ) =>
      NoShowDisputeService.handleNoShowReport(
        bookingId,
        playerId,
        stadiumLat,
        stadiumLng,
      );

  /// Forwarder to NoShowDisputeService for backward compatibility.
  static Future<bool> disputeNoShowWithGPS({
    required String bookingId,
    required String playerId,
    required double stadiumLat,
    required double stadiumLng,
  }) =>
      NoShowDisputeService.disputeNoShowWithGPS(
        bookingId: bookingId,
        playerId: playerId,
        stadiumLat: stadiumLat,
        stadiumLng: stadiumLng,
      );

  /// Forwarder to NoShowDisputeService for backward compatibility.
  static Future<bool> disputeWithGeotaggedSelfie({
    required String bookingId,
    required String playerId,
    required String photoUrl,
    required double stadiumLat,
    required double stadiumLng,
  }) =>
      NoShowDisputeService.disputeWithGeotaggedSelfie(
        bookingId: bookingId,
        playerId: playerId,
        photoUrl: photoUrl,
        stadiumLat: stadiumLat,
        stadiumLng: stadiumLng,
      );
}