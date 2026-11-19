import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/analytics_service.dart';
import 'package:vsp_application/core/services/retention_event_contract.dart';

void main() {
  final first = DateTime.utc(2026, 11, 1, 20);

  bool active({
    String role = 'player',
    bool consent = true,
    bool identity = true,
    String firstEvent = VSPAnalyticsEvents.bookingCompleted,
    String returnEvent = VSPAnalyticsEvents.matchViewed,
    DateTime? returned,
    int day = 7,
  }) => VSPActiveReturnContract.isActiveReturn(
        role: role, consented: consent, stableAuthenticatedIdentity: identity,
        firstValueEvent: firstEvent, firstValueAt: first,
        returnEvent: returnEvent,
        returnedAt: returned ?? DateTime.utc(2026, 11, 8, 15),
        day: day,
      );

  test('active return is a subsequent meaningful player event, not app launch', () {
    expect(active(), isTrue);
    expect(active(returnEvent: VSPAnalyticsEvents.appOpened), isFalse);
    expect(active(returnEvent: VSPAnalyticsEvents.signupCompleted), isFalse);
    expect(active(returnEvent: VSPAnalyticsEvents.ownerDashboardViewed), isFalse);
    expect(active(firstEvent: VSPAnalyticsEvents.bookingStarted), isFalse);
  });

  test('UTC calendar day window is strict, not a 24-hour duration approximation', () {
    expect(active(returned: DateTime.utc(2026, 11, 7, 23, 59)), isFalse);
    expect(active(returned: DateTime.utc(2026, 11, 8, 0, 0)), isTrue);
    expect(active(returned: DateTime.utc(2026, 11, 9, 0, 0)), isFalse);
    expect(active(returned: DateTime.utc(2026, 11, 2, 0, 1), day: 1), isTrue);
    expect(active(returned: DateTime.utc(2026, 12, 1, 0, 1), day: 30), isTrue);
    expect(active(returned: first, day: 1), isFalse);
    expect(active(day: 9), isFalse);
  });

  test('cannot count unconsented, anonymous or cross-role activity', () {
    expect(active(consent: false), isFalse);
    expect(active(identity: false), isFalse);
    expect(active(role: 'admin'), isFalse);
    expect(active(role: ''), isFalse);
    expect(active(firstEvent: VSPAnalyticsEvents.ownerDashboardViewed), isFalse);
  });

  test('owner first value and return use independent owner events', () {
    expect(active(
      role: 'owner',
      firstEvent: VSPAnalyticsEvents.ownerDashboardViewed,
      returnEvent: VSPAnalyticsEvents.subscriptionViewed,
    ), isTrue);
    expect(active(
      role: 'owner',
      firstEvent: VSPAnalyticsEvents.ownerDashboardViewed,
      returnEvent: VSPAnalyticsEvents.venueViewed,
    ), isFalse);
  });

  test('same instant with different time-zone offsets is not a return', () {
    final utc = DateTime.utc(2026, 4, 23, 10);
    expect(VSPActiveReturnContract.isActiveReturn(
      role: 'player', consented: true, stableAuthenticatedIdentity: true,
      firstValueEvent: VSPAnalyticsEvents.teamCreated,
      firstValueAt: utc,
      returnEvent: VSPAnalyticsEvents.matchViewed,
      returnedAt: DateTime.parse('2026-04-23T13:00:00+03:00'),
      day: 1,
    ), isFalse);
  });

  test('event dictionary aligns with the analytics source of truth', () {
    for (final name in <String>{
      ...VSPActiveReturnContract.playerFirstValueEvents,
      ...VSPActiveReturnContract.ownerFirstValueEvents,
      ...VSPActiveReturnContract.playerReturnEvents,
      ...VSPActiveReturnContract.ownerReturnEvents,
    }) {
      expect(VSPAnalyticsEvents.conversionFunnel.contains(name) ||
          name == VSPAnalyticsEvents.ownerDashboardViewed, isTrue);
      expect(name, isNot(VSPAnalyticsEvents.appOpened));
    }
  });
}
