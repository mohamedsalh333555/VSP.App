import 'analytics_service.dart';

/// Pure, privacy-preserving definition of "active return" (54.01).
/// Analytics identity and consent are caller verified: this class never
/// accepts, stores or transmits account IDs, raw event payloads or tokens.
abstract final class VSPActiveReturnContract {
  static const Set<int> measuredDays = <int>{1, 7, 30};

  // First value is a confirmed action, never opening a screen or checkout.
  static const Set<String> playerFirstValueEvents = <String>{
    VSPAnalyticsEvents.bookingCompleted,
    VSPAnalyticsEvents.matchJoined,
    VSPAnalyticsEvents.teamCreated,
  };
  static const Set<String> ownerFirstValueEvents = <String>{
    VSPAnalyticsEvents.ownerDashboardViewed,
    VSPAnalyticsEvents.subscriptionActivated,
  };

  // A return must include a meaningful player/owner action, not a passive
  // app_opened, push impression, rebuild or repeated screen lifecycle event.
  static const Set<String> playerReturnEvents = <String>{
    VSPAnalyticsEvents.venueViewed,
    VSPAnalyticsEvents.bookingStarted,
    VSPAnalyticsEvents.bookingCompleted,
    VSPAnalyticsEvents.matchViewed,
    VSPAnalyticsEvents.matchJoined,
    VSPAnalyticsEvents.teamCreated,
  };
  static const Set<String> ownerReturnEvents = <String>{
    VSPAnalyticsEvents.ownerDashboardViewed,
    VSPAnalyticsEvents.subscriptionViewed,
    VSPAnalyticsEvents.subscriptionActivated,
  };

  static bool isActiveReturn({
    required String role,
    required bool consented,
    required bool stableAuthenticatedIdentity,
    required String firstValueEvent,
    required DateTime firstValueAt,
    required String returnEvent,
    required DateTime returnedAt,
    required int day,
  }) {
    if (!consented || !stableAuthenticatedIdentity || !measuredDays.contains(day)) {
      return false;
    }
    final firstValueSet = role == 'player'
        ? playerFirstValueEvents
        : role == 'owner'
            ? ownerFirstValueEvents
            : const <String>{};
    final returnSet = role == 'player'
        ? playerReturnEvents
        : role == 'owner'
            ? ownerReturnEvents
            : const <String>{};
    if (!firstValueSet.contains(firstValueEvent) || !returnSet.contains(returnEvent)) {
      return false;
    }
    final origin = firstValueAt.toUtc();
    final revisit = returnedAt.toUtc();
    if (!revisit.isAfter(origin)) return false;
    // UTC calendar dates avoid elapsed-hour drift during Cairo DST changes.
    final d0 = DateTime.utc(origin.year, origin.month, origin.day);
    final dReturn = DateTime.utc(revisit.year, revisit.month, revisit.day);
    return dReturn.difference(d0).inDays == day;
  }
}
