import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/navigation/app_route_role_guard.dart';

void main() {
  test('billing paths are reserved for authenticated owners', () {
    for (final path in ['/owner', '/owner-ledger', '/subscription-plans']) {
      expect(AppRouteRoleGuard.isOwnerOnly(path), true);
      expect(AppRouteRoleGuard.redirectForRole(
        path: path, isOwner: false, isAdmin: false,
      ), '/');
      expect(AppRouteRoleGuard.redirectForRole(
        path: path, isOwner: true, isAdmin: false,
      ), isNull);
    }
  });

  test('GoRouter registers explicit owner billing destinations behind global guard', () {
    final source = File('lib/core/navigation/app_router.dart').readAsStringSync();
    expect(source, contains("path: '/subscription-plans'"));
    expect(source, contains('const SubscriptionPlansScreen()'));
    expect(source, contains("path: '/owner-ledger'"));
    expect(source, contains('const OwnerLedgerScreen()'));
    final hydrated = source.indexOf('if (userModel.isBlocked)');
    final guard = source.indexOf('AppRouteRoleGuard.redirectForRole(');
    final ownerFlow = source.indexOf('// 8. Owner flow gating');
    expect(hydrated, greaterThanOrEqualTo(0));
    expect(guard, greaterThan(hydrated));
    expect(ownerFlow, greaterThan(guard));
    expect(source, contains('if (roleRedirect != null) return roleRedirect;'));
  });

  test('in-app notification cannot imperatively open billing screen for player', () {
    final source = File(
      'lib/features/player/screens/notifications_center_screen.dart',
    ).readAsStringSync();
    final checkpoint = source.indexOf(
      'final mayOpenOwnerBilling = currentAuth.isOwner &&',
    );
    final subscription = source.indexOf("if (type == 'subscription')", checkpoint);
    final subscriptionGuard = source.indexOf(
      'if (!mayOpenOwnerBilling) return;', subscription,
    );
    final subscriptionPush = source.indexOf('const SubscriptionPlansScreen()', subscription);
    final ledger = source.indexOf("if (type == 'payout'", subscriptionPush);
    final ledgerGuard = source.indexOf('if (!mayOpenOwnerBilling) return;', ledger);
    final ledgerPush = source.indexOf('const OwnerLedgerScreen()', ledger);
    expect(checkpoint, greaterThanOrEqualTo(0));
    expect(subscriptionGuard, greaterThan(subscription));
    expect(subscriptionPush, greaterThan(subscriptionGuard));
    expect(ledgerGuard, greaterThan(ledger));
    expect(ledgerPush, greaterThan(ledgerGuard));
    expect(source, contains('currentAuth.currentUser?.id == userId'));
    expect(source, contains('currentAuth.userModel?.isBlocked != true'));
  });

  test('push notification billing links use guarded GoRouter paths', () {
    final source = File('lib/core/services/notification_service.dart')
        .readAsStringSync();
    expect(source, contains("GoRouter.of(context).push('/subscription-plans')"));
    expect(source, contains("GoRouter.of(context).push('/owner-ledger')"));
    expect(source, contains('NotificationFilterService.isRecipientCurrentUser('));
    expect(source, contains('NotificationFilterService.resolveDeepLinkRoute(data)'));
  });
}
