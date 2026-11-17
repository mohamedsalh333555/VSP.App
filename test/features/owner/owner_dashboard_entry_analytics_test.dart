import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/analytics_service.dart';

void main() {
  test('owner dashboard hook is restricted to owner-role visible home', () {
    final source = File(
      'lib/features/owner/screens/owner_dashboard_screen.dart',
    ).readAsStringSync();

    expect(source, contains('if (widget.isHomeVisible) {'));
    expect(source, contains('AnalyticsService.logOwnerDashboardViewed(ownerId: ownerId)'));
    expect(source, contains('final uid = auth.isOwner ? auth.currentUser?.id : null;'));
    expect(source, contains('if (uid == null) return;'));
    expect(source, contains('AnalyticsService.logOwnerDashboardViewed(ownerId: uid)'));
    expect(source, contains('if (!oldWidget.isHomeVisible && widget.isHomeVisible)'));
    expect(source, contains('onHomeBecameVisible();'));
    expect(source, isNot(contains('AnalyticsService.logSubscriptionActivated(')));
  });

  test('owner home event deduplicates rebuilds but not distinct owners', () {
    final registry = AnalyticsSessionDedupe();
    var delivered = 0;

    Future<bool> view(String ownerId) => registry.sendOnce(
      name: VSPAnalyticsEvents.ownerDashboardViewed,
      dedupeKey: 'owner_dashboard_viewed:$ownerId',
      send: () async {
        delivered++;
        return true;
      },
    );

    return () async {
      expect(await view('owner-first'), isTrue);
      expect(await view('owner-first'), isFalse);
      expect(await view('owner-second'), isTrue);
      expect(delivered, 2);
    }();
  });

  test('retry after offline failure is allowed for the same owner', () async {
    final dedupe = AnalyticsSessionDedupe();
    var attempts = 0;
    Future<bool> view() => dedupe.sendOnce(
      name: VSPAnalyticsEvents.ownerDashboardViewed,
      dedupeKey: 'owner_dashboard_viewed:owner',
      send: () async => ++attempts > 1,
    );
    expect(await view(), isFalse);
    expect(await view(), isTrue);
    expect(await view(), isFalse);
    expect(attempts, 2);
  });

  test('owner account IDs are only part of in-process dedupe, never payload', () {
    final source = File(
      'lib/core/services/analytics_service.dart',
    ).readAsStringSync();
    final start = source.indexOf('static Future<void> logOwnerDashboardViewed(');
    final next = source.indexOf('static Future<void> logSubscriptionViewed()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(next, greaterThan(start));
    final method = source.substring(start, next);
    expect(method, contains("name: VSPAnalyticsEvents.ownerDashboardViewed,"));
    expect(method, contains("dedupeKey: 'owner_dashboard_viewed:"));
    expect(method, isNot(contains("parameters: {'owner_id':")));
    final sanitized = AnalyticsService.privacySafeParameters({
      'owner_id': 'secret-owner-id',
      'role': 'owner',
    });
    expect(sanitized, {'role': 'owner'});
  });

  test('pricing visit is not a paid subscription activation', () {
    final pricing = File(
      'lib/features/owner/screens/subscription_plans_screen.dart',
    ).readAsStringSync();
    expect(pricing, contains('AnalyticsService.logSubscriptionViewed()'));
    expect(pricing, isNot(contains('AnalyticsService.logSubscriptionActivated(')));
  });
}
