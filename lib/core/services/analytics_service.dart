import 'package:firebase_analytics/firebase_analytics.dart';

import 'logger_service.dart';

/// Privacy-conscious analytics for product funnels.
///
/// UI code should prefer the typed helpers below. They keep event names
/// consistent and make rebuild-sensitive events idempotent within the current
/// app session. Never pass names, email addresses, phone numbers, auth tokens,
/// free-form messages, or payment credentials as analytics parameters.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: _analytics);

  static final Set<String> _sessionDedupeKeys = <String>{};

  static const Set<String> _sensitiveParameterFragments = <String>{
    'email',
    'phone',
    'mobile',
    'name',
    'token',
    'password',
    'message',
    'address',
  };

  static Map<String, Object> privacySafeParameters(
    Map<String, Object>? parameters,
  ) {
    if (parameters == null || parameters.isEmpty) return const {};

    return Map<String, Object>.unmodifiable(
      Map<String, Object>.fromEntries(
        parameters.entries.where((entry) {
          final key = entry.key.toLowerCase();
          return !_sensitiveParameterFragments.any(key.contains);
        }),
      ),
    );
  }

  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      final safeParameters = privacySafeParameters(parameters);
      await _analytics.logEvent(
        name: name,
        parameters: safeParameters.isEmpty ? null : safeParameters,
      );
      VSPLogger.i('Analytics Event: $name | $safeParameters');
    } catch (e) {
      // Analytics is auxiliary and must never block a user journey.
      VSPLogger.e('Analytics Error: $e');
    }
  }

  /// Logs an event at most once for [dedupeKey] during this process lifetime.
  ///
  /// This prevents duplicate funnel entries caused by widget rebuilds or
  /// retries while still allowing callers to choose a distinct key for a
  /// genuinely new action.
  static Future<void> logOncePerSession({
    required String name,
    required String dedupeKey,
    Map<String, Object>? parameters,
  }) async {
    if (!_sessionDedupeKeys.add(dedupeKey)) return;
    await logEvent(name: name, parameters: parameters);
  }

  static Future<void> setUserProperties({
    required String userId,
    String? role,
    String? governorate,
  }) async {
    await _analytics.setUserId(id: userId);
    if (role != null) {
      await _analytics.setUserProperty(name: 'user_role', value: role);
    }
    if (governorate != null) {
      await _analytics.setUserProperty(
        name: 'governorate',
        value: governorate,
      );
    }
  }

  // Phase 10 conversion funnel events. Parameters are deliberately categorical.
  static Future<void> logAppOpened() => logOncePerSession(
        name: 'app_opened',
        dedupeKey: 'app_opened',
      );

  static Future<void> logOnboardingStarted() => logOncePerSession(
        name: 'onboarding_started',
        dedupeKey: 'onboarding_started',
      );

  static Future<void> logSignupCompleted({required String role}) => logEvent(
        name: 'signup_completed',
        parameters: {'role': role},
      );

  static Future<void> logVenueViewed({required String venueId}) =>
      logOncePerSession(
        name: 'venue_viewed',
        dedupeKey: 'venue_viewed:$venueId',
      );

  static Future<void> logBookingStarted({required String venueId}) =>
      logOncePerSession(
        name: 'booking_started',
        dedupeKey: 'booking_started:$venueId',
      );

  static Future<void> logBookingCompleted({required String paymentMethod}) =>
      logEvent(
        name: 'booking_completed',
        parameters: {'payment_method': paymentMethod},
      );

  static Future<void> logMatchViewed({required String matchId}) =>
      logOncePerSession(
        name: 'match_viewed',
        dedupeKey: 'match_viewed:$matchId',
      );

  static Future<void> logTeamCreated({required String sportType}) => logEvent(
        name: 'team_created',
        parameters: {'sport_type': sportType},
      );

  static Future<void> logOwnerRegistrationStarted() => logOncePerSession(
        name: 'owner_registration_started',
        dedupeKey: 'owner_registration_started',
      );

  static Future<void> logOwnerRegistrationCompleted() => logEvent(
        name: 'owner_registration_completed',
      );

  static Future<void> logSubscriptionViewed() => logOncePerSession(
        name: 'subscription_viewed',
        dedupeKey: 'subscription_viewed',
      );

  static Future<void> logSubscriptionActivated({
    required String planCode,
  }) =>
      logEvent(
        name: 'subscription_activated',
        parameters: {'plan_code': planCode},
      );

  // Existing product events retained for compatibility.
  static Future<void> logMatchJoined(String bookingId, String type) =>
      logOncePerSession(
        name: 'match_joined',
        dedupeKey: 'match_joined:$bookingId',
        parameters: {'type': type},
      );

  static Future<void> logStadiumBooked(String stadiumId, double price) async {
    await logEvent(
      name: 'stadium_booked',
      parameters: {'stadium_id': stadiumId, 'price': price},
    );
  }

  static Future<void> logChallengeSent(
    String fromTeam,
    String toTeam,
  ) async {
    await logEvent(
      name: 'challenge_sent',
      parameters: {'from_team': fromTeam, 'to_team': toTeam},
    );
  }

  static Future<void> logRankUp(int oldRank, int newRank) async {
    await logEvent(
      name: 'rank_up',
      parameters: {'old_rank': oldRank, 'new_rank': newRank},
    );
  }

  static Future<void> logChatMessageSent(String type) async {
    await logEvent(
      name: 'chat_message_sent',
      parameters: {'message_type': type},
    );
  }
}
