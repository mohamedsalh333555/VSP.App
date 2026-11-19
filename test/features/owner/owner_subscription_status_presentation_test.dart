import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/features/owner/widgets/subscription/owner_subscription_status_presentation.dart';

void main() {
  final now = DateTime.utc(2026, 11, 18, 12);
  UserModel account({
    String plan = 'basic',
    DateTime? trialEnd,
    DateTime? paidEnd,
    String role = 'owner',
  }) => UserModel(
    uid: 'owner-fixture',
    email: 'fixture@example.invalid',
    role: role,
    subscriptionPlan: plan,
    trialEndsAt: trialEnd,
    subscriptionExpiresAt: paidEnd,
  );

  test('current paid Pro is distinct from active trial, even on same account', () {
    final yesterday = now.subtract(const Duration(days: 1));
    final tomorrow = now.add(const Duration(days: 1));
    final paid = OwnerSubscriptionStatusPresentation.stateFor(
      account(plan: 'pro', paidEnd: tomorrow, trialEnd: yesterday), now,
    );
    final trial = OwnerSubscriptionStatusPresentation.stateFor(
      account(plan: 'pro', paidEnd: yesterday, trialEnd: tomorrow), now,
    );
    expect(paid, OwnerSubscriptionBadgeState.pro);
    expect(trial, OwnerSubscriptionBadgeState.trial);
    expect(OwnerSubscriptionStatusPresentation.label(
      paid, isArabic: false,
    ), 'Pro subscription');
    expect(OwnerSubscriptionStatusPresentation.label(
      trial, isArabic: false,
    ), 'Pro trial');
  });

  test('exact expiry never labels unpaid or expired Pro as active', () {
    expect(OwnerSubscriptionStatusPresentation.stateFor(
      account(plan: 'pro', paidEnd: now), now,
    ), OwnerSubscriptionBadgeState.proExpired);
    expect(OwnerSubscriptionStatusPresentation.stateFor(
      account(plan: 'free_trial', trialEnd: now), now,
    ), OwnerSubscriptionBadgeState.trialExpired);
    expect(OwnerSubscriptionStatusPresentation.getIsWarning(
      OwnerSubscriptionBadgeState.proExpired,
    ), isTrue);
    expect(OwnerSubscriptionStatusPresentation.getIsActivePro(
      OwnerSubscriptionBadgeState.proExpired,
    ), isFalse);
  });

  test('Free and unstarted trial do not claim paid access', () {
    for (final plan in ['basic', 'free', 'free_trial']) {
      expect(OwnerSubscriptionStatusPresentation.stateFor(
        account(plan: plan), now,
      ), OwnerSubscriptionBadgeState.free);
    }
    expect(OwnerSubscriptionStatusPresentation.getIsActivePro(
      OwnerSubscriptionBadgeState.free,
    ), isFalse);
  });

  test('unexpected plan and non-owner identities do not claim Free or Pro', () {
    expect(OwnerSubscriptionStatusPresentation.stateFor(
      account(plan: 'unknown'), now,
    ), OwnerSubscriptionBadgeState.unavailable);
    expect(OwnerSubscriptionStatusPresentation.stateFor(
      account(plan: 'pro', role: 'player', paidEnd: now.add(const Duration(days: 1))), now,
    ), OwnerSubscriptionBadgeState.unavailable);
    expect(OwnerSubscriptionStatusPresentation.stateFor(null, now),
        OwnerSubscriptionBadgeState.unavailable);
  });

  test('Arabic and English labels give an unambiguous current status', () {
    final labels = <OwnerSubscriptionBadgeState, String>{
      OwnerSubscriptionBadgeState.pro: 'اشتراك Pro',
      OwnerSubscriptionBadgeState.trial: 'تجربة Pro',
      OwnerSubscriptionBadgeState.proExpired: 'انتهى اشتراك Pro',
      OwnerSubscriptionBadgeState.trialExpired: 'انتهت التجربة',
      OwnerSubscriptionBadgeState.free: 'مجاني',
      OwnerSubscriptionBadgeState.unavailable: 'الاشتراك غير متاح',
    };
    for (final entry in labels.entries) {
      expect(OwnerSubscriptionStatusPresentation.label(
        entry.key, isArabic: true,
      ), entry.value);
      expect(OwnerSubscriptionStatusPresentation.label(
        entry.key, isArabic: false,
      ), isNotEmpty);
    }
  });

  test('dashboard renders the true status, pricing remains server sourced', () {
    final header = File(
      'lib/features/owner/widgets/dashboard/owner_dashboard_header.dart',
    ).readAsStringSync();
    final plans = File(
      'lib/features/owner/screens/subscription_plans_screen.dart',
    ).readAsStringSync();
    expect(header, contains('OwnerSubscriptionStatusPresentation.stateFor('));
    expect(header, contains('OwnerSubscriptionStatusPresentation.label('));
    expect(header, contains('subscriptionLabel,'));
    expect(header, contains('subscriptionBadgeColor'));
    expect(header, contains('عرض باقات الاشتراك'));
    expect(header, contains('View subscription plans'));
    expect(header, isNot(contains('1000 ج.م')));
    expect(header, isNot(contains('1000 EGP')));
    expect(plans, contains('fetchPublicPlans()'));
    expect(plans, isNot(contains('AnalyticsService.logSubscriptionActivated(')));
  });
}
