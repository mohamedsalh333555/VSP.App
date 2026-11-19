import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/analytics_service.dart';
import 'package:vsp_application/core/services/retention_cohort_contract.dart';

VSPRetentionCohortEvent e(
  String account,
  String role,
  String event,
  String instant, {
  bool consent = true,
  bool authenticated = true,
}) => VSPRetentionCohortEvent(
  accountKey: account,
  role: role,
  name: event,
  happenedAt: DateTime.parse(instant),
  analyticsConsented: consent,
  authenticated: authenticated,
);

void main() {
  test('UTC D1/D7/D30 denominator matures independently; one account once', () {
    final signals = <VSPRetentionCohortEvent>[];
    for (var i = 0; i < 6; i++) {
      final id = 'person-$i';
      signals.add(e(id, 'player', VSPAnalyticsEvents.bookingCompleted, '2026-11-01T23:55:00+02:00'));
      signals.add(e(id, 'player', VSPAnalyticsEvents.appOpened, '2026-11-02T00:00:00Z'));
      if (i < 3) {
        signals.add(e(id, 'player', VSPAnalyticsEvents.matchViewed, '2026-11-02T07:00:00Z'));
        signals.add(e(id, 'player', VSPAnalyticsEvents.matchViewed, '2026-11-02T11:00:00Z'));
      }
      if (i < 2) signals.add(e(id, 'player', VSPAnalyticsEvents.matchJoined, '2026-11-08T16:00:00Z'));
      if (i == 0) signals.add(e(id, 'player', VSPAnalyticsEvents.teamCreated, '2026-12-01T02:00:00Z'));
    }
    final segment = VSPRetentionCohorts.segment(events: signals,
      observedThrough: DateTime.utc(2026, 11, 10),
    ).single;
    expect(segment.role, 'player');
    expect(segment.accounts, 6);
    expect([segment.eligibleD1, segment.activeD1], [6, 3]);
    expect([segment.eligibleD7, segment.activeD7], [6, 2]);
    expect([segment.eligibleD30, segment.activeD30], [0, 0]);
    expect(segment.d1Rate, 0.5);
    expect(segment.d30Rate, isNull);
    final matured = VSPRetentionCohorts.segment(events: signals,
      observedThrough: DateTime.utc(2026, 12, 2),
    ).single;
    expect([matured.eligibleD30, matured.activeD30], [6, 1]);
  });

  test('dashboard cohort export hides small active and inactive counts', () {
    final events = <VSPRetentionCohortEvent>[];
    for (var i = 0; i < 10; i++) {
      events.add(e('private-$i', 'player',
          VSPAnalyticsEvents.bookingCompleted, '2026-11-01T08:00:00Z'));
      if (i < 6) {
        events.add(e('private-$i', 'player',
            VSPAnalyticsEvents.matchViewed, '2026-11-02T08:00:00Z'));
      }
    }
    final segment = VSPRetentionCohorts.segment(
      events: events, observedThrough: DateTime.utc(2026, 12, 10),
    ).single;
    expect(segment.activeD1, 6);
    final payload = segment.toPrivacySafeJson();
    expect(payload['accounts'], 10);
    expect(payload['eligibleD1'], 10);
    // 10 - 6 reveals a group of four; do not publish active=6.
    expect(payload['activeD1'], isNull);
    expect(payload['activeD7'], 0);
    expect(payload['eligibleD7'], 10);
    expect(payload.toString(), isNot(contains('private-')));
  });

  test('cohort export masks small eligible day counts', () {
    final segment = VSPRetentionCohortSegment(
      role: 'owner', firstValueEvent: VSPAnalyticsEvents.ownerDashboardViewed,
      cohortDayUtc: DateTime.utc(2026, 11, 1), accounts: 8,
      eligibleD1: 3, activeD1: 1,
      eligibleD7: 0, activeD7: 0,
      eligibleD30: 0, activeD30: 0,
    );
    final result = segment.toPrivacySafeJson();
    expect(result['eligibleD1'], isNull);
    expect(result['activeD1'], isNull);
    expect(result['eligibleD7'], isNull);
    expect(result['activeD7'], isNull);
    expect(result['eligibleD30'], isNull);
    expect(result['activeD30'], isNull);
  });

  test('eligible cohort sizes cannot reveal a four-person unmatured group', () {
    const firstValue = VSPAnalyticsEvents.bookingCompleted;
    final report = VSPRetentionCohortSegment(
      role: 'player',
      firstValueEvent: firstValue,
      cohortDayUtc: DateTime.utc(2026, 11, 1),
      accounts: 10,
      eligibleD1: 6, activeD1: 6,
      eligibleD7: 6, activeD7: 0,
      eligibleD30: 0, activeD30: 0,
    ).toPrivacySafeJson();
    expect(report['accounts'], 10);
    expect(report['eligibleD1'], isNull);
    expect(report['activeD1'], isNull);
    expect(report['eligibleD7'], isNull);
    expect(report['eligibleD30'], isNull);
  });

  test('intermediate eligible-day gap suppresses later day counts', () {
    final report = VSPRetentionCohortSegment(
      role: 'owner',
      firstValueEvent: VSPAnalyticsEvents.ownerDashboardViewed,
      cohortDayUtc: DateTime.utc(2026, 11, 1),
      accounts: 20,
      eligibleD1: 20, activeD1: 15,
      eligibleD7: 16, activeD7: 10,
      eligibleD30: 0, activeD30: 0,
    ).toPrivacySafeJson();
    expect(report['eligibleD1'], 20);
    expect(report['activeD1'], 15);
    expect(report['eligibleD7'], isNull);
    expect(report['activeD7'], isNull);
    expect(report['eligibleD30'], isNull);
  });

  test('untrusted small or inconsistent segments cannot be serialized', () {
    VSPRetentionCohortSegment segment({
      int accounts = 10, int eligibleD1 = 10, int eligibleD7 = 10,
      String role = 'player',
      String event = VSPAnalyticsEvents.bookingCompleted,
    }) => VSPRetentionCohortSegment(
      role: role, firstValueEvent: event,
      cohortDayUtc: DateTime.utc(2026, 11, 1),
      accounts: accounts, eligibleD1: eligibleD1, activeD1: 0,
      eligibleD7: eligibleD7, activeD7: 0,
      eligibleD30: 0, activeD30: 0,
    );
    expect(() => segment(accounts: 4, eligibleD1: 4, eligibleD7: 4)
        .toPrivacySafeJson(), throwsStateError);
    expect(() => segment(eligibleD1: 11).toPrivacySafeJson(), throwsStateError);
    expect(() => segment(eligibleD7: 11).toPrivacySafeJson(), throwsStateError);
    expect(() => segment(role: 'invalid').toPrivacySafeJson(), throwsStateError);
    expect(() => segment(event: 'personal_identifier')
        .toPrivacySafeJson(), throwsStateError);
  });

  test('roles, first value, unconsented and anonymous records never mix', () {
    final signals = <VSPRetentionCohortEvent>[];
    for (var i = 0; i < 5; i++) {
      signals.add(e('player-$i', 'player', VSPAnalyticsEvents.bookingCompleted,
          '2026-11-01T09:00:00Z'));
      signals.add(e('owner-$i', 'owner', VSPAnalyticsEvents.ownerDashboardViewed,
          '2026-11-01T09:00:00Z'));
      signals.add(e('owner-$i', 'owner', VSPAnalyticsEvents.subscriptionViewed,
          '2026-11-02T12:00:00Z'));
      // Owner events may not count as player returns.
      signals.add(e('player-$i', 'player', VSPAnalyticsEvents.ownerDashboardViewed,
          '2026-11-02T12:00:00Z'));
    }
    signals.add(e('unconsented', 'player', VSPAnalyticsEvents.bookingCompleted,
        '2026-11-01T09:00:00Z', consent: false));
    signals.add(e('anonymous', 'player', VSPAnalyticsEvents.bookingCompleted,
        '2026-11-01T09:00:00Z', authenticated: false));
    signals.add(e('', 'player', VSPAnalyticsEvents.bookingCompleted, '2026-11-01T09:00:00Z'));
    final reports = VSPRetentionCohorts.segment(events: signals,
      observedThrough: DateTime.utc(2026, 11, 9));
    expect(reports.length, 2);
    final player = reports.singleWhere((s) => s.role == 'player');
    final owner = reports.singleWhere((s) => s.role == 'owner');
    expect(player.accounts, 5);
    expect(player.activeD1, 0);
    expect(owner.accounts, 5);
    expect(owner.activeD1, 5);
  });

  test('first value is earliest confirmed event; input ordering is irrelevant', () {
    final signals = <VSPRetentionCohortEvent>[];
    for (var i = 0; i < 5; i++) {
      signals.add(e('$i', 'player', VSPAnalyticsEvents.bookingCompleted, '2026-11-05T00:00:00Z'));
      signals.add(e('$i', 'player', VSPAnalyticsEvents.teamCreated, '2026-11-01T00:00:00Z'));
      signals.add(e('$i', 'player', VSPAnalyticsEvents.bookingStarted, '2026-11-02T12:00:00Z'));
      signals.add(e('$i', 'player', VSPAnalyticsEvents.signupCompleted, '2026-10-01T00:00:00Z'));
    }
    final a = VSPRetentionCohorts.segment(events: signals,
      observedThrough: DateTime.utc(2026, 11, 9)).single;
    final b = VSPRetentionCohorts.segment(events: signals.reversed,
      observedThrough: DateTime.utc(2026, 11, 9)).single;
    expect(a.firstValueEvent, VSPAnalyticsEvents.teamCreated);
    expect(a.cohortDayUtc, DateTime.utc(2026, 11, 1));
    expect(a.activeD1, 5);
    expect(b.accounts, a.accounts);
    expect(b.activeD1, a.activeD1);
  });

  test('small cohorts are suppressed, identity is not copied into report', () {
    final signals = [
      for (var i = 0; i < 4; i++)
        e('private-account-$i', 'player', VSPAnalyticsEvents.bookingCompleted, '2026-11-01T00:00:00Z'),
    ];
    expect(VSPRetentionCohorts.segment(events: signals,
      observedThrough: DateTime.utc(2026, 11, 8)), isEmpty);
    signals.add(e('private-account-4', 'player', VSPAnalyticsEvents.bookingCompleted,
        '2026-11-01T00:00:00Z'));
    final segment = VSPRetentionCohorts.segment(events: signals,
      observedThrough: DateTime.utc(2026, 11, 8)).single;
    expect(segment.accounts, 5);
    expect(segment.toString().contains('private-account-'), isFalse);
  });

  test('future events are excluded and UTC timezone offsets do not shift cohorts', () {
    final signals = <VSPRetentionCohortEvent>[
      for (var i = 0; i < 5; i++) ...[
        e('player-$i', 'player', VSPAnalyticsEvents.bookingCompleted,
            '2026-04-23T23:50:00+03:00'),
        e('player-$i', 'player', VSPAnalyticsEvents.matchViewed,
            '2026-04-24T00:10:00+03:00'),
        e('player-$i', 'player', VSPAnalyticsEvents.matchViewed,
            '2026-04-24T00:10:00Z'),
      ],
    ];
    final report = VSPRetentionCohorts.segment(events: signals,
      observedThrough: DateTime.parse('2026-04-24T00:20:00Z')).single;
    expect(report.cohortDayUtc, DateTime.utc(2026, 4, 23));
    expect(report.activeD1, 5);
  });
}
