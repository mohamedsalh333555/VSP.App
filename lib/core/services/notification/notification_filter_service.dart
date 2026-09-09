import 'package:shared_preferences/shared_preferences.dart';

/// Pure logic service for filtering notifications according to user preferences
/// and resolving deep link routes from notification payloads.
class NotificationFilterService {
  const NotificationFilterService._();

  /// Maps notification [type] to the corresponding SharedPreferences toggle key.
  static String? getPrefKeyForType(String? type) {
    if (type == null) return null;
    switch (type) {
      case 'chat':
        return 'notif_chat';
      case 'booking_new':
      case 'booking_confirmed':
      case 'booking_cancelled':
        return 'notif_cash_bookings';
      case 'team_transfer':
      case 'team_invite':
      case 'info':
        return 'notif_team_transfers';
      case 'match_reminder':
        return 'notif_match_reminders';
      case 'challenge':
      case 'challenge_accepted':
      case 'challenge_declined':
        return 'notif_challenge_results';
      default:
        return null;
    }
  }

  /// Evaluates whether a notification of [type] should be displayed.
  static Future<bool> shouldShowNotification(
    String? type, {
    SharedPreferences? prefs,
  }) async {
    try {
      final preferences = prefs ?? await SharedPreferences.getInstance();
      final general = preferences.getBool('notif_general') ?? true;
      if (!general) return false;

      final key = getPrefKeyForType(type);
      if (key == null) return true;

      return preferences.getBool(key) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Determines the deep-link route for a given notification payload.
  /// Returns a route string like `/match/123`, `/team/456`, or `/notifications`.
  static String resolveDeepLinkRoute(Map<String, dynamic> data) {
    final String? bookingId = data['bookingId']?.toString();
    final String? teamId = data['teamId']?.toString();

    if (bookingId != null && bookingId.isNotEmpty) {
      return '/match/$bookingId';
    }

    if (teamId != null && teamId.isNotEmpty) {
      return '/team/$teamId';
    }

    return '/notifications';
  }
}
