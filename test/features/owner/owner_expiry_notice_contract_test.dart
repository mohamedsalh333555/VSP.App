import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/features/owner/widgets/subscription/owner_plan_expiry_presentation.dart';

void main() {
  final now = DateTime.utc(2026, 11, 18, 12);
  UserModel account({
    required String plan,
    DateTime? trialEnd,
    DateTime? paidEnd,
    String role = 'owner',
  }) => UserModel(
    uid: 'offline-fixture',
    role: role,
    email: 'placeholder@example.invalid',
    subscriptionPlan: plan,
    trialEndsAt: trialEnd,
    subscriptionExpiresAt: paidEnd,
  );

  test('exact expiry instant becomes expired, earlier instant is active', () {
    final justBefore = now.subtract(const Duration(microseconds: 1));
    expect(OwnerPlanExpiryPresentation.stateFor(
      account(plan: 'pro', paidEnd: now), justBefore,
    ), OwnerPlanExpiryState.none);
    expect(OwnerPlanExpiryPresentation.stateFor(
      account(plan: 'pro', paidEnd: now), now,
    ), OwnerPlanExpiryState.paidExpired);

    expect(OwnerPlanExpiryPresentation.stateFor(
      account(plan: 'free_trial', trialEnd: now), now,
    ), OwnerPlanExpiryState.trialExpired);
    expect(OwnerPlanExpiryPresentation.stateFor(
      account(plan: 'free_trial', trialEnd: now.add(const Duration(microseconds: 1))), now,
    ), OwnerPlanExpiryState.none);
  });

  test('timezone representation does not cause premature expiry', () {
    final endsAt = DateTime.parse('2026-11-18T14:00:00+02:00');
    expect(OwnerPlanExpiryPresentation.stateFor(
      account(plan: 'pro', paidEnd: endsAt),
      now.subtract(const Duration(seconds: 1)),
    ), OwnerPlanExpiryState.none);
    expect(OwnerPlanExpiryPresentation.stateFor(
      account(plan: 'pro', paidEnd: endsAt), now,
    ), OwnerPlanExpiryState.paidExpired);
  });

  test('no warning for free or non-owner accounts, including stale paid dates', () {
    final yesterday = now.subtract(const Duration(days: 1));
    for (final user in [
      account(plan: 'basic', paidEnd: yesterday),
      account(plan: 'pro', paidEnd: yesterday, role: 'player'),
      account(plan: 'basic'),
    ]) {
      expect(OwnerPlanExpiryPresentation.stateFor(user, now),
          OwnerPlanExpiryState.none);
    }
  });

  test('a valid paid or trial term suppresses a misleading expiry warning', () {
    final yesterday = now.subtract(const Duration(days: 1));
    final tomorrow = now.add(const Duration(days: 1));
    expect(OwnerPlanExpiryPresentation.stateFor(
      account(plan: 'pro', paidEnd: yesterday, trialEnd: tomorrow), now,
    ), OwnerPlanExpiryState.none);
    expect(OwnerPlanExpiryPresentation.stateFor(
      account(plan: 'pro', paidEnd: tomorrow, trialEnd: yesterday), now,
    ), OwnerPlanExpiryState.none);
  });

  test('notices distinguish trial versus paid renewal in both languages', () {
    final arabicTrial = OwnerPlanExpiryPresentation.message(
        OwnerPlanExpiryState.trialExpired, isArabic: true);
    final englishTrial = OwnerPlanExpiryPresentation.message(
        OwnerPlanExpiryState.trialExpired, isArabic: false);
    final arabicPaid = OwnerPlanExpiryPresentation.message(
        OwnerPlanExpiryState.paidExpired, isArabic: true);
    final englishPaid = OwnerPlanExpiryPresentation.message(
        OwnerPlanExpiryState.paidExpired, isArabic: false);

    expect(arabicTrial, contains('تجربة'));
    expect(englishTrial, contains('trial'));
    expect(arabicPaid, contains('تجديد'));
    expect(englishPaid, contains('renew'));
    expect(arabicTrial, isNot(arabicPaid));
    expect(englishTrial, isNot(englishPaid));
    for (final state in OwnerPlanExpiryState.values) {
      if (state == OwnerPlanExpiryState.none) {
        expect(OwnerPlanExpiryPresentation.message(
            state, isArabic: true), isEmpty);
        expect(OwnerPlanExpiryPresentation.message(
            state, isArabic: false), isEmpty);
      }
    }
  });

  test('notice is UI-only and rendered only for actual expired state', () {
    final screen = File('lib/features/owner/screens/subscription_plans_screen.dart')
        .readAsStringSync();
    final presentation = File(
      'lib/features/owner/widgets/subscription/owner_plan_expiry_presentation.dart',
    ).readAsStringSync();
    expect(screen, contains('OwnerPlanExpiryPresentation.stateFor(userModel, DateTime.now())'));
    expect(screen, contains('if (expiryState != OwnerPlanExpiryState.none)'));
    expect(screen, contains('OwnerPlanExpiryPresentation.message('));
    expect(screen, contains('VSPColors.warning'));
    expect(presentation, isNot(contains('.update(')));
    expect(presentation, isNot(contains('Supabase.instance')));
  });
}
