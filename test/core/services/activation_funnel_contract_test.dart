import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/activation_funnel_contract.dart';
import 'package:vsp_application/core/services/analytics_service.dart';
import 'package:vsp_application/core/services/retention_cohort_contract.dart';

VSPRetentionCohortEvent signal(
  String account,
  String role,
  String name,
  String instant, {
  bool consent = true,
  bool authenticated = true,
}) => VSPRetentionCohortEvent(
  accountKey: account,
  role: role,
  name: name,
  happenedAt: DateTime.parse(instant),
  analyticsConsented: consent,
  authenticated: authenticated,
);

void main() {
  final cutoff = DateTime.utc(2026, 11, 17);
  const booking = [
    VSPAnalyticsEvents.appOpened,
    VSPAnalyticsEvents.signupCompleted,
    VSPAnalyticsEvents.venueViewed,
    VSPAnalyticsEvents.bookingStarted,
    VSPAnalyticsEvents.bookingCompleted,
  ];

  test('orders the booking funnel by unique account and confirmed success', () {
    final events = <VSPRetentionCohortEvent>[];
    for (var i = 0; i < 10; i++) {
      for (var s = 0; s < booking.length; s++) {
        if (s == 4 && i >= 6) continue;
        events.add(signal(
          'player-$i',
          'player',
          booking[s],
          '2026-11-01T0$s:00:00Z',
        ));
      }
      // Rebuilds/repeated opens do not create extra users.
      events.add(signal('player-$i', 'player', booking[0],
          '2026-11-01T00:15:00Z'));
    }
    final report = VSPActivationFunnels.build(
      journey: 'player_booking', events: events.reversed, observedThrough: cutoff)!;
    expect(report.role, 'player');
    expect(report.stages.map((e) => e.accounts).toList(), [10, 10, 10, 10, null]);
    expect(report.stages.last.conversionFromPrevious, isNull,
        reason: 'Four dropped accounts are suppressed, not shown as a percent');
    expect(report.stages.last.dropOffFromPrevious, isNull);
    expect(report.stages[3].conversionFromPrevious, 1);
  });

  test('small adjacent drop-offs cannot be inferred by subtraction', () {
    final events = <VSPRetentionCohortEvent>[];
    for (var i = 0; i < 10; i++) {
      for (var s = 0; s < booking.length; s++) {
        if (s == 2 && i >= 6) break;
        events.add(signal('p-$i', 'player', booking[s],
            '2026-11-01T0$s:00:00Z'));
      }
    }
    final report = VSPActivationFunnels.build(
      journey: 'player_booking', events: events, observedThrough: cutoff,
    )!;
    // 10 -> 6 would reveal four people leaving if both were published.
    expect(report.stages[0].accounts, 10);
    expect(report.stages[1].accounts, 10);
    expect(report.stages[2].accounts, isNull);
    expect(report.stages[2].dropOffFromPrevious, isNull);
    // Subsequent raw stages also contain six; avoid revealing the gap
    // by publishing a later stage when an intermediate count is hidden.
    expect(report.stages[3].accounts, isNull);
    expect(report.stages[4].accounts, isNull);
    final exported = report.toJson().toString();
    expect(exported, isNot(contains('accounts: 6')));
    expect(exported, isNot(contains('dropOffFromPrevious: 4')));
  });

  test('mature transitions are visible if drop-off is at least five', () {
    final events = <VSPRetentionCohortEvent>[];
    for (var i = 0; i < 12; i++) {
      for (var s = 0; s < booking.length; s++) {
        if (s == 4 && i >= 5) continue;
        events.add(signal('player-$i', 'player', booking[s],
            '2026-11-01T0$s:00:00Z'));
      }
    }
    final report = VSPActivationFunnels.build(
        journey: 'player_booking', events: events, observedThrough: cutoff)!;
    expect(report.stages.last.accounts, 5);
    expect(report.stages.last.dropOffFromPrevious, 7);
    expect(report.stages.last.conversionFromPrevious, closeTo(5 / 12, 0.001));
  });

  test('does not count steps out of order or imply paid subscription', () {
    final events = <VSPRetentionCohortEvent>[];
    for (var i = 0; i < 6; i++) {
      events.add(signal('owner-$i', 'owner',
          VSPAnalyticsEvents.ownerDashboardViewed, '2026-11-01T08:00:00Z'));
      events.add(signal('owner-$i', 'owner',
          VSPAnalyticsEvents.subscriptionViewed, '2026-11-02T08:00:00Z'));
      // Checkout started does not prove a paid activation.
      events.add(signal('owner-$i', 'owner',
          VSPAnalyticsEvents.bookingStarted, '2026-11-03T08:00:00Z'));
      events.add(signal('owner-$i', 'owner',
          VSPAnalyticsEvents.subscriptionActivated, '2026-10-31T08:00:00Z'));
    }
    final report = VSPActivationFunnels.build(
        journey: 'owner_subscription', events: events, observedThrough: cutoff)!;
    expect(report.stages[0].accounts, 6);
    expect(report.stages[1].accounts, 6);
    expect(report.stages.last.accounts, 0);
    expect(report.stages.last.dropOffFromPrevious, 6);
  });

  test('requires consent, authentication, role and observation cutoff', () {
    final events = <VSPRetentionCohortEvent>[];
    for (var i = 0; i < 5; i++) {
      for (var s = 0; s < booking.length; s++) {
        events.add(signal('consented-$i', 'player', booking[s],
            '2026-11-01T0$s:00:00Z'));
      }
    }
    // All of these would inflate the report if the privacy gate regressed.
    for (var s = 0; s < booking.length; s++) {
      events.add(signal('anonymous', 'player', booking[s],
          '2026-11-01T0$s:00:00Z', authenticated: false));
      events.add(signal('opted-out', 'player', booking[s],
          '2026-11-01T0$s:00:00Z', consent: false));
      events.add(signal('wrong-role', 'owner', booking[s],
          '2026-11-01T0$s:00:00Z'));
      events.add(signal('future', 'player', booking[s],
          '2026-12-01T0$s:00:00Z'));
    }
    final report = VSPActivationFunnels.build(
        journey: 'player_booking', events: events, observedThrough: cutoff)!;
    expect(report.stages.last.accounts, 5);
    expect(report.stages.first.accounts, 5);
    expect(report.stages.first.event, VSPAnalyticsEvents.appOpened);
    expect(report.toString().contains('consented-'), isFalse);
  });

  test('suppresses small cohorts and intermediate stages', () {
    final onlyFour = <VSPRetentionCohortEvent>[
      for (var i = 0; i < 4; i++)
        signal('private-$i', 'player', booking.first,
            '2026-11-01T00:00:00Z'),
    ];
    expect(VSPActivationFunnels.build(
      journey: 'player_booking', events: onlyFour, observedThrough: cutoff,
    ), isNull);

    final events = <VSPRetentionCohortEvent>[];
    for (var i = 0; i < 8; i++) {
      events.add(signal('private-$i', 'player',
          booking[0], '2026-11-01T00:00:00Z'));
      if (i < 4) events.add(signal('private-$i', 'player',
          booking[1], '2026-11-02T00:00:00Z'));
    }
    final report = VSPActivationFunnels.build(
        journey: 'player_booking', events: events, observedThrough: cutoff)!;
    expect(report.stages.first.accounts, 8);
    expect(report.stages[1].accounts, isNull);
    expect(report.stages[1].conversionFromPrevious, isNull);
  });

  test('JSON export contains only aggregate fields, never account keys', () {
    final events = <VSPRetentionCohortEvent>[];
    for (var i = 0; i < 5; i++) {
      for (var s = 0; s < booking.length; s++) {
        events.add(signal('private-key-$i', 'player', booking[s],
            '2026-11-01T0$s:00:00Z'));
      }
    }
    final report = VSPActivationFunnels.build(
        journey: 'player_booking', events: events, observedThrough: cutoff)!;
    final payload = report.toJson();
    expect(payload.keys, containsAll([
      'journey', 'role', 'observedThroughUtc', 'stages',
    ]));
    expect(payload.toString().contains('private-key'), isFalse);
    final stages = payload['stages'] as List;
    expect(stages.length, 5);
    expect((stages.last as Map)['accounts'], 5);
  });

  test('rejects unknown journey rather than fabricating a metric', () {
    expect(() => VSPActivationFunnels.build(
      journey: 'made_up', events: const <VSPRetentionCohortEvent>[],
      observedThrough: cutoff,
    ), throwsArgumentError);
  });
}
