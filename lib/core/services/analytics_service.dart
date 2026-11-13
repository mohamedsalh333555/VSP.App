import 'package:firebase_analytics/firebase_analytics.dart';

import 'logger_service.dart';

abstract final class VSPAnalyticsEvents {
  static const appOpened = 'app_opened';
  static const onboardingStarted = 'onboarding_started';
  static const signupCompleted = 'signup_completed';
  static const venueViewed = 'venue_viewed';
  static const bookingStarted = 'booking_started';
  static const bookingCompleted = 'booking_completed';
  static const matchViewed = 'match_viewed';
  static const matchJoined = 'match_joined';
  static const teamCreated = 'team_created';
  static const ownerRegistrationStarted = 'owner_registration_started';
  static const ownerRegistrationCompleted = 'owner_registration_completed';
  static const ownerDashboardViewed = 'owner_dashboard_viewed';
  static const subscriptionViewed = 'subscription_viewed';
  static const subscriptionActivated = 'subscription_activated';

  static const conversionFunnel = <String>{
    appOpened,
    onboardingStarted,
    signupCompleted,
    venueViewed,
    bookingStarted,
    bookingCompleted,
    matchViewed,
    matchJoined,
    teamCreated,
    ownerRegistrationStarted,
    ownerRegistrationCompleted,
    subscriptionViewed,
    subscriptionActivated,
  };
}

/// Deterministic in-process funnel deduplication; no Firebase dependency.
/// Event names are part of the key so unrelated event types cannot collide.
class AnalyticsSessionDedupe {
  final Set<String> _seen = <String>{};

  String _eventKey(String name, String dedupeKey) =>
      '${name.length}:$name:$dedupeKey';

  bool markFirst({required String name, required String dedupeKey}) =>
      _seen.add(_eventKey(name, dedupeKey));

  /// Reserve before the async write to block concurrent duplicate events.
  /// Allow a retry when the sender reports a failure or throws (e.g. offline).
  Future<bool> sendOnce({
    required String name,
    required String dedupeKey,
    required Future<bool> Function() send,
  }) async {
    final key = _eventKey(name, dedupeKey);
    if (!_seen.add(key)) return false;
    try {
      if (await send()) return true;
      _seen.remove(key);
      return false;
    } catch (_) {
      _seen.remove(key);
      rethrow;
    }
  }
}

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

  static final AnalyticsSessionDedupe _sessionDedupe = AnalyticsSessionDedupe();

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

  static Future<bool> _sendEvent({
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
      return true;
    } catch (e) {
      // Analytics is auxiliary and must never block a user journey.
      VSPLogger.e('Analytics Error: $e');
      return false;
    }
  }

  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _sendEvent(name: name, parameters: parameters);
  }

  /// Duplicate calls in one session are suppressed only after delivery.
  /// If Firebase reports an offline/transport failure, another trigger can retry.
  static Future<void> logOncePerSession({
    required String name,
    required String dedupeKey,
    Map<String, Object>? parameters,
  }) async {
    await _sessionDedupe.sendOnce(
      name: name,
      dedupeKey: dedupeKey,
      send: () => _sendEvent(name: name, parameters: parameters),
    );
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
        name: VSPAnalyticsEvents.appOpened,
        dedupeKey: 'app_opened',
      );

  static Future<void> logOnboardingStarted() => logOncePerSession(
        name: VSPAnalyticsEvents.onboardingStarted,
        dedupeKey: 'onboarding_started',
      );

  static Future<void> logSignupCompleted({required String role}) => logEvent(
        name: VSPAnalyticsEvents.signupCompleted,
        parameters: {'role': role},
      );

  static Future<void> logVenueViewed({required String venueId}) =>
      logOncePerSession(
        name: VSPAnalyticsEvents.venueViewed,
        dedupeKey: 'venue_viewed:$venueId',
      );

  static Future<void> logBookingStarted({required String venueId}) =>
      logOncePerSession(
        name: VSPAnalyticsEvents.bookingStarted,
        dedupeKey: 'booking_started:$venueId',
      );

  static Future<void> logBookingCompleted({
    required String bookingId,
    required String paymentMethod,
  }) =>
      logOncePerSession(
        name: VSPAnalyticsEvents.bookingCompleted,
        dedupeKey: 'booking_completed:$bookingId',
        parameters: {'payment_method': paymentMethod},
      );

  static Future<void> logMatchViewed({required String matchId}) =>
      logOncePerSession(
        name: VSPAnalyticsEvents.matchViewed,
        dedupeKey: 'match_viewed:$matchId',
      );

  static Future<void> logTeamCreated({required String sportType}) => logEvent(
        name: VSPAnalyticsEvents.teamCreated,
        parameters: {'sport_type': sportType},
      );

  static Future<void> logOwnerRegistrationStarted() => logOncePerSession(
        name: VSPAnalyticsEvents.ownerRegistrationStarted,
        dedupeKey: 'owner_registration_started',
      );

  static Future<void> logOwnerRegistrationCompleted() => logEvent(
        name: VSPAnalyticsEvents.ownerRegistrationCompleted,
      );

  /// First dashboard entry per owner account in the current app session.
  static Future<void> logOwnerDashboardViewed({required String ownerId}) =>
      logOncePerSession(
        name: VSPAnalyticsEvents.ownerDashboardViewed,
        dedupeKey: 'owner_dashboard_viewed:$ownerId',
      );

  static Future<void> logSubscriptionViewed() => logOncePerSession(
        name: VSPAnalyticsEvents.subscriptionViewed,
        dedupeKey: 'subscription_viewed',
      );

  static Future<void> logSubscriptionActivated({
    required String planCode,
  }) =>
      logEvent(
        name: VSPAnalyticsEvents.subscriptionActivated,
        parameters: {'plan_code': planCode},
      );

  // Existing product events retained for compatibility.
  static Future<void> logMatchJoined(String bookingId, String type) =>
      logOncePerSession(
        name: VSPAnalyticsEvents.matchJoined,
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
