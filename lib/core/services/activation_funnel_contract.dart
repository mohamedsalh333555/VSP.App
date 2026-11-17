import 'analytics_service.dart';
import 'retention_cohort_contract.dart';

/// One privacy-preserving stage in a chronological, account-level funnel.
class VSPFunnelStage {
  final String event;
  /// Null means suppressed for small groups, not "zero users".
  final int? accounts;
  /// Transition from the previous step; null for the first/suppressed stage.
  final double? conversionFromPrevious;
  /// Suppressed when its magnitude could reveal a small group.
  final int? dropOffFromPrevious;

  const VSPFunnelStage({
    required this.event,
    required this.accounts,
    required this.conversionFromPrevious,
    required this.dropOffFromPrevious,
  });
}

class VSPFunnelReport {
  final String journey;
  final String role;
  final DateTime observedThroughUtc;
  final List<VSPFunnelStage> stages;

  const VSPFunnelReport({
    required this.journey,
    required this.role,
    required this.observedThroughUtc,
    required this.stages,
  });

  /// Export aggregates ONLY. Never include account keys or event timelines.
  Map<String, Object?> toJson() => {
        'journey': journey,
        'role': role,
        'observedThroughUtc': observedThroughUtc.toIso8601String(),
        'stages': [
          for (final stage in stages)
            {
              'event': stage.event,
              'accounts': stage.accounts,
              'conversionFromPrevious': stage.conversionFromPrevious,
              'dropOffFromPrevious': stage.dropOffFromPrevious,
            },
        ],
      };
}

/// Offline analytical contract for 50.04/50.05.
///
/// The source is a consent-checked, authenticated event stream. Raw account
/// keys are only used transiently for unique-account deduplication and never
/// returned or logged. This class does not fetch Firebase, Supabase or live
/// customer data. A null report means the cohort was too small to publish.
abstract final class VSPActivationFunnels {
  static const int minimumReportable = 5;

  static const Map<String, (String, List<String>)> journeys = {
    'player_booking': (
      'player',
      [
        VSPAnalyticsEvents.appOpened,
        VSPAnalyticsEvents.signupCompleted,
        VSPAnalyticsEvents.venueViewed,
        VSPAnalyticsEvents.bookingStarted,
        VSPAnalyticsEvents.bookingCompleted,
      ],
    ),
    'player_match': (
      'player',
      [
        VSPAnalyticsEvents.appOpened,
        VSPAnalyticsEvents.signupCompleted,
        VSPAnalyticsEvents.matchViewed,
        VSPAnalyticsEvents.matchJoined,
      ],
    ),
    'owner_activation': (
      'owner',
      [
        VSPAnalyticsEvents.appOpened,
        VSPAnalyticsEvents.ownerRegistrationStarted,
        VSPAnalyticsEvents.ownerRegistrationCompleted,
        VSPAnalyticsEvents.ownerDashboardViewed,
      ],
    ),
    'owner_subscription': (
      'owner',
      [
        VSPAnalyticsEvents.ownerDashboardViewed,
        VSPAnalyticsEvents.subscriptionViewed,
        VSPAnalyticsEvents.subscriptionActivated,
      ],
    ),
  };

  static VSPFunnelReport? build({
    required String journey,
    required Iterable<VSPRetentionCohortEvent> events,
    required DateTime observedThrough,
  }) {
    final definition = journeys[journey];
    if (definition == null) {
      throw ArgumentError.value(journey, 'journey', 'Unknown funnel');
    }
    final role = definition.$1;
    final steps = definition.$2;
    final cutoff = observedThrough.toUtc();
    final accounts = <String, List<VSPRetentionCohortEvent>>{};
    for (final event in events) {
      if (event.role != role ||
          !event.authenticated ||
          !event.analyticsConsented ||
          event.accountKey.trim().isEmpty ||
          event.happenedAt.toUtc().isAfter(cutoff)) {
        continue;
      }
      accounts.putIfAbsent(event.accountKey, () => []).add(event);
    }

    final counts = List<int>.filled(steps.length, 0);
    for (final accountEvents in accounts.values) {
      // Evaluate each stage independently so unordered imports and same-
      // timestamp events cannot accidentally change a user's progression.
      DateTime? previous;
      for (var index = 0; index < steps.length; index++) {
        DateTime? earliest;
        for (final event in accountEvents) {
          if (event.name != steps[index]) continue;
          final time = event.happenedAt.toUtc();
          if (previous != null && time.isBefore(previous)) continue;
          if (earliest == null || time.isBefore(earliest)) earliest = time;
        }
        if (earliest == null) break;
        previous = earliest;
        counts[index]++;
      }
    }
    if (counts.first < minimumReportable) return null;

    int? publish(int value) =>
        value == 0 || value >= minimumReportable ? value : null;

    final stages = <VSPFunnelStage>[];
    for (var index = 0; index < steps.length; index++) {
      final prior = index == 0 ? null : counts[index - 1];
      final current = counts[index];
      final visiblePrior = prior == null ? null : publish(prior);
      final visibleCurrent = publish(current);
      final delta = prior == null ? null : prior - current;
      // Hide small drop-offs even when both headline counts are visible.
      final visibleDelta = delta == null ? null : publish(delta);
      final rate = visiblePrior != null &&
              visiblePrior > 0 &&
              visibleCurrent != null &&
              visibleDelta != null
          ? current / prior!
          : null;
      stages.add(VSPFunnelStage(
        event: steps[index],
        accounts: visibleCurrent,
        conversionFromPrevious: rate,
        dropOffFromPrevious: visibleDelta,
      ));
    }
    return VSPFunnelReport(
      journey: journey,
      role: role,
      observedThroughUtc: cutoff,
      stages: List<VSPFunnelStage>.unmodifiable(stages),
    );
  }
}
