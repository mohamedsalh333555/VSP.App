import 'package:shared_preferences/shared_preferences.dart';

/// Pure logic service for filtering notifications according to user preferences
/// and resolving deep link routes from notification payloads.
class NotificationFilterService {
  const NotificationFilterService._();

  /// Maps notification [type] to the corresponding SharedPreferences toggle key.
  static String? getPrefKeyForType(String? type, {bool isOwner = false}) {
    // Older push producers may use uppercase, kebab-case or spaces.
    // Normalize these to the same user-visible preference category.
    final normalizedType = type?.trim().toLowerCase()
        .replaceAll('-', '_').replaceAll(' ', '_');
    if (normalizedType == null || normalizedType.isEmpty) return null;
    if (isOwner) {
      switch (normalizedType) {
        case 'chat':
          return 'notif_chat';
        case 'booking_new':
        case 'booking_confirmed':
        case 'booking_cancelled':
        case 'booking_reminder':
          return 'notif_owner_new_bookings';
        case 'payout':
        case 'debt_warning':
        case 'debt_grace':
          return 'notif_owner_payouts';
        case 'daily_schedule':
          return 'notif_owner_daily_schedule';
        default:
          return null;
      }
    }

    switch (normalizedType) {
      case 'chat':
        return 'notif_chat';
      case 'booking_new':
      case 'booking_confirmed':
      case 'booking_cancelled':
      case 'booking_reminder':
        return 'notif_cash_bookings';
      case 'team_transfer':
      case 'team_invite':
      case 'info':
        return 'notif_team_transfers';
      case 'match_reminder':
      case 'match_start_reminder':
        return 'notif_match_reminders';
      case 'challenge':
      case 'challenge_confirmed':
      case 'challenge_accepted':
      case 'challenge_declined':
      case 'challenge_result':
        return 'notif_challenge_results';
      case 'join_request_declined':
        return 'notif_match_reminders';
      default:
        return null;
    }
  }

  /// Keys match the notification settings screen and are always scoped to the
  /// active account. Unscoped legacy device keys are never used for alerts.
  static String scopedPrefKey(String userId, String key) =>
      'vsp_user_${userId}_$key';

  /// Push metadata is an untrusted routing hint. Require a recipient that
  /// matches the active account before showing any foreground alert.
  /// This is a privacy guard, not a replacement for server token ownership.
  static bool isRecipientCurrentUser(
    Map<String, dynamic> payload, String? activeUserId,
  ) {
    if (activeUserId == null || activeUserId.trim().isEmpty) return false;
    final recipient = payload['recipientUserId'] ?? payload['recipient_user_id'];
    return recipient is String && recipient == activeUserId;
  }

  /// Foreground-only preference check. Never import settings from another
  /// account (including unscoped keys left by older app versions).
  static Future<bool> shouldShowNotificationForUser(
    String? type, {
    required String userId,
    SharedPreferences? prefs,
    bool isOwner = false,
  }) async {
    if (userId.trim().isEmpty) return false;
    try {
      final preferences = prefs ?? await SharedPreferences.getInstance();
      if (preferences.getBool(scopedPrefKey(userId, 'notif_general')) == false) {
        return false;
      }
      final category = getPrefKeyForType(type, isOwner: isOwner);
      if (category == null) return true;
      return preferences.getBool(scopedPrefKey(userId, category)) ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Evaluates whether a notification of [type] should be displayed.
  static Future<bool> shouldShowNotification(
    String? type, {
    SharedPreferences? prefs,
    bool isOwner = false,
  }) async {
    try {
      final preferences = prefs ?? await SharedPreferences.getInstance();
      final general = preferences.getBool('notif_general') ?? true;
      if (!general) return false;

      final key = getPrefKeyForType(type, isOwner: isOwner);
      if (key == null) return true;

      return preferences.getBool(key) ?? true;
    } catch (_) {
      // A storage failure must not bypass an explicit opt-out. When we
      // cannot read preferences, avoid displaying an unsolicited alert.
      return false;
    }
  }

  /// Validates a route segment from untrusted notification metadata.
  static String? _safeRouteId(dynamic value) {
    if (value is! String) return null;
    final id = value.trim();
    // IDs are single path segments, never routes or arbitrary user content.
    // Reject slash, percent-encoded slashes, query/fragment delimiters and
    // control characters instead of letting notification payloads redirect.
    if (id.isEmpty || id.length > 128 ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      return null;
    }
    return id;
  }

  /// Resolves a safe match/team route or falls back to the inbox.
  static String resolveDeepLinkRoute(Map<String, dynamic> data) {
    final bookingId = _safeRouteId(data['bookingId']) ??
        _safeRouteId(data['booking_id']);
    final teamId = _safeRouteId(data['teamId']) ??
        _safeRouteId(data['team_id']);

    // Never accept a raw path from notification metadata. Only validated IDs
    // can select a destination; actual account authorization is checked by
    // the destination screen.
    if (bookingId != null) return '/match/$bookingId';
    if (teamId != null) return '/team/$teamId';
    return '/notifications';
  }
}
