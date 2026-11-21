import 'retention_event_contract.dart';

/// A pre-consented, authenticated event. `accountKey` is used transiently
/// for deduplication, never copied into the aggregate return value.
class VSPRetentionCohortEvent {
  final String accountKey;
  final String role;
  final String name;
  final DateTime happenedAt;
  final bool analyticsConsented;
  final bool authenticated;

  const VSPRetentionCohortEvent({
    required this.accountKey,
    required this.role,
    required this.name,
    required this.happenedAt,
    required this.analyticsConsented,
    required this.authenticated,
  });
}

class VSPRetentionCohortSegment {
  final String role;
  final String firstValueEvent;
  final DateTime cohortDayUtc;
  final int accounts;
  final int eligibleD1;
  final int activeD1;
  final int eligibleD7;
  final int activeD7;
  final int eligibleD30;
  final int activeD30;

  const VSPRetentionCohortSegment({
    required this.role,
    required this.firstValueEvent,
    required this.cohortDayUtc,
    required this.accounts,
    required this.eligibleD1,
    required this.activeD1,
    required this.eligibleD7,
    required this.activeD7,
    required this.eligibleD30,
    required this.activeD30,
  });

  /// Privacy-safe local dashboard export. Raw small cohort activity is not
  /// serialized. Also avoid inferring a small *inactive* group by subtracting
  /// a published active count from an eligible denominator.
  Map<String, Object?> toPrivacySafeJson() {
    // Only cohort segments created from a known first-value event may be
    // exported. A manually constructed four-person group must not bypass
    // the minimum cell-size threshold through direct serialization.
    final firstValueSet = role == 'owner'
        ? VSPActiveReturnContract.ownerFirstValueEvents
        : role == 'player'
            ? VSPActiveReturnContract.playerFirstValueEvents
            : const <String>{};
    if (accounts < VSPRetentionCohorts.minimumReportableCohort ||
        !firstValueSet.contains(firstValueEvent) ||
        eligibleD1 < 0 || eligibleD1 > accounts ||
        eligibleD7 < 0 || eligibleD7 > eligibleD1 ||
        eligibleD30 < 0 || eligibleD30 > eligibleD7 ||
        activeD1 < 0 || activeD1 > eligibleD1 ||
        activeD7 < 0 || activeD7 > eligibleD7 ||
        activeD30 < 0 || activeD30 > eligibleD30) {
      throw StateError('Unsafe or invalid retention cohort export');
    }
    int? safeCount(int count) => count == 0 ||
            count >= VSPRetentionCohorts.minimumReportableCohort
        ? count
        : null;

    // A cohort of ten with six eligible accounts exposes the other four by
    // subtraction even when activity is hidden. Mask such eligibility cells,
    // and continue masking all later eligible-day cells once any is hidden.
    (int?, int?) day(int eligible, int active, int? priorPublishedEligible) {
      if (priorPublishedEligible == null) return (null, null);
      final notYetEligible = priorPublishedEligible - eligible;
      if (notYetEligible > 0 &&
          notYetEligible < VSPRetentionCohorts.minimumReportableCohort) {
        return (null, null);
      }
      final visibleEligible = safeCount(eligible);
      if (visibleEligible == null) return (null, null);
      final inactive = eligible - active;
      final safeActive = inactive == 0 ||
              inactive >= VSPRetentionCohorts.minimumReportableCohort
          ? safeCount(active)
          : null;
      return (visibleEligible, safeActive);
    }

    final d1 = day(eligibleD1, activeD1, accounts);
    final d7 = day(eligibleD7, activeD7, d1.$1);
    final d30 = day(eligibleD30, activeD30, d7.$1);
    return {
      'role': role,
      'firstValueEvent': firstValueEvent,
      'cohortDayUtc': cohortDayUtc.toIso8601String(),
      'accounts': accounts,
      'eligibleD1': d1.$1,
      'activeD1': d1.$2,
      'eligibleD7': d7.$1,
      'activeD7': d7.$2,
      'eligibleD30': d30.$1,
      'activeD30': d30.$2,
    };
  }

  double? get d1Rate => eligibleD1 == 0 ? null : activeD1 / eligibleD1;
  double? get d7Rate => eligibleD7 == 0 ? null : activeD7 / eligibleD7;
  double? get d30Rate => eligibleD30 == 0 ? null : activeD30 / eligibleD30;
}

class _CohortCounts {
  int accounts = 0;
  int eligibleD1 = 0;
  int activeD1 = 0;
  int eligibleD7 = 0;
  int activeD7 = 0;
  int eligibleD30 = 0;
  int activeD30 = 0;
}

/// Privacy-first in-memory cohort segment contract (54.02).
/// Neither identity, event payloads nor individual activity timelines are
/// returned. This is NOT a data collector or a live retention dashboard.
abstract final class VSPRetentionCohorts {
  /// Suppress tiny cohorts rather than disclosing single-person activity.
  static const int minimumReportableCohort = 5;

  static DateTime _utcDate(DateTime value) {
    final utc = value.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  static List<VSPRetentionCohortSegment> segment({
    required Iterable<VSPRetentionCohortEvent> events,
    required DateTime observedThrough,
  }) {
    final observationEnd = observedThrough.toUtc();
    final observationDay = _utcDate(observationEnd);
    // A role is part of the deduplication key. Owner actions must never count
    // as player activity or migrate into the player's cohort denominator.
    final byAccountRole = <(String, String), List<VSPRetentionCohortEvent>>{};
    for (final event in events) {
      if (event.accountKey.trim().isEmpty ||
          !event.analyticsConsented ||
          !event.authenticated ||
          (event.role != 'player' && event.role != 'owner') ||
          event.happenedAt.toUtc().isAfter(observationEnd)) {
        continue;
      }
      byAccountRole
          .putIfAbsent((event.accountKey, event.role), () => [])
          .add(event);
    }

    final counts = <(String, String, DateTime), _CohortCounts>{};
    for (final entry in byAccountRole.entries) {
      final role = entry.key.$2;
      final firstSet = role == 'player'
          ? VSPActiveReturnContract.playerFirstValueEvents
          : VSPActiveReturnContract.ownerFirstValueEvents;
      VSPRetentionCohortEvent? first;
      for (final event in entry.value) {
        if (!firstSet.contains(event.name)) continue;
        if (first == null ||
            event.happenedAt.toUtc().isBefore(first.happenedAt.toUtc()) ||
            (event.happenedAt.toUtc().isAtSameMomentAs(first.happenedAt) &&
                event.name.compareTo(first.name) < 0)) {
          first = event;
        }
      }
      if (first == null) continue;
      final day = _utcDate(first.happenedAt);
      final key = (role, first.name, day);
      final count = counts.putIfAbsent(key, _CohortCounts.new);
      count.accounts++;

      final matureDays = observationDay.difference(day).inDays;
      final returned = <int>{};
      for (final event in entry.value) {
        for (final offset in VSPActiveReturnContract.measuredDays) {
          if (matureDays < offset || returned.contains(offset)) continue;
          if (VSPActiveReturnContract.isActiveReturn(
            role: role,
            consented: event.analyticsConsented,
            stableAuthenticatedIdentity: event.authenticated,
            firstValueEvent: first.name,
            firstValueAt: first.happenedAt,
            returnEvent: event.name,
            returnedAt: event.happenedAt,
            day: offset,
          )) {
            returned.add(offset);
          }
        }
      }
      if (matureDays >= 1) {
        count.eligibleD1++;
        if (returned.contains(1)) count.activeD1++;
      }
      if (matureDays >= 7) {
        count.eligibleD7++;
        if (returned.contains(7)) count.activeD7++;
      }
      if (matureDays >= 30) {
        count.eligibleD30++;
        if (returned.contains(30)) count.activeD30++;
      }
    }

    final result = <VSPRetentionCohortSegment>[];
    for (final entry in counts.entries) {
      final count = entry.value;
      // Do not publish small group totals or their zero/one return flags.
      if (count.accounts < minimumReportableCohort) continue;
      result.add(VSPRetentionCohortSegment(
        role: entry.key.$1,
        firstValueEvent: entry.key.$2,
        cohortDayUtc: entry.key.$3,
        accounts: count.accounts,
        eligibleD1: count.eligibleD1,
        activeD1: count.activeD1,
        eligibleD7: count.eligibleD7,
        activeD7: count.activeD7,
        eligibleD30: count.eligibleD30,
        activeD30: count.activeD30,
      ));
    }
    result.sort((a, b) {
      final byDay = a.cohortDayUtc.compareTo(b.cohortDayUtc);
      if (byDay != 0) return byDay;
      final byRole = a.role.compareTo(b.role);
      return byRole != 0 ? byRole : a.firstValueEvent.compareTo(b.firstValueEvent);
    });
    return List<VSPRetentionCohortSegment>.unmodifiable(result);
  }
}
