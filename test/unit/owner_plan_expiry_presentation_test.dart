import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/features/owner/widgets/subscription/owner_plan_expiry_presentation.dart';

void main() {
  final now = DateTime.utc(2026, 11, 13, 12);
  UserModel owner({
    String plan = 'basic',
    DateTime? trial,
    DateTime? paid,
    String role = 'owner',
  }) => UserModel(
    uid: 'fixture-owner',
    role: role,
    subscriptionPlan: plan,
    trialEndsAt: trial,
    subscriptionExpiresAt: paid,
  );

  test('paid Pro expiration is distinct from active Pro', () {
    final past = now.subtract(const Duration(days: 1));
    final future = now.add(const Duration(days: 1));
    expect(
      OwnerPlanExpiryPresentation.stateFor(owner(plan: 'pro', paid: past), now),
      OwnerPlanExpiryState.paidExpired,
    );
    expect(
      OwnerPlanExpiryPresentation.stateFor(owner(plan: 'pro', paid: future), now),
      OwnerPlanExpiryState.none,
    );
  });

  test('expired trial falls back to free-facing notice without altering a plan', () {
    final past = now.subtract(const Duration(seconds: 1));
    final future = now.add(const Duration(days: 4));
    expect(
      OwnerPlanExpiryPresentation.stateFor(
        owner(plan: 'free_trial', trial: past),
        now,
      ),
      OwnerPlanExpiryState.trialExpired,
    );
    expect(
      OwnerPlanExpiryPresentation.stateFor(
        owner(plan: 'free_trial', trial: future),
        now,
      ),
      OwnerPlanExpiryState.none,
    );
  });

  test('free owners and non-owner roles receive no misleading expiry message', () {
    expect(
      OwnerPlanExpiryPresentation.stateFor(owner(), now),
      OwnerPlanExpiryState.none,
    );
    expect(
      OwnerPlanExpiryPresentation.stateFor(
        owner(plan: 'pro', paid: now.subtract(const Duration(days: 1)), role: 'player'),
        now,
      ),
      OwnerPlanExpiryState.none,
    );
    expect(
      OwnerPlanExpiryPresentation.message(
        OwnerPlanExpiryState.none, isArabic: true,
      ),
      isEmpty,
    );
  });

  test('active trial remains active even while a previous paid term has expired', () {
    expect(
      OwnerPlanExpiryPresentation.stateFor(
        owner(
          plan: 'pro',
          paid: now.subtract(const Duration(days: 1)),
          trial: now.add(const Duration(days: 1)),
        ),
        now,
      ),
      OwnerPlanExpiryState.none,
    );
  });

  test('Arabic and English distinguish trial and subscription expiry', () {
    final trialAr = OwnerPlanExpiryPresentation.message(
      OwnerPlanExpiryState.trialExpired, isArabic: true,
    );
    final paidAr = OwnerPlanExpiryPresentation.message(
      OwnerPlanExpiryState.paidExpired, isArabic: true,
    );
    final trialEn = OwnerPlanExpiryPresentation.message(
      OwnerPlanExpiryState.trialExpired, isArabic: false,
    );
    final paidEn = OwnerPlanExpiryPresentation.message(
      OwnerPlanExpiryState.paidExpired, isArabic: false,
    );
    expect(trialAr, contains('تجربة'));
    expect(paidAr, contains('اشتراك'));
    expect(trialEn, contains('trial'));
    expect(paidEn, contains('subscription'));
  });

  test('owner subscription plans screen renders expiry warning only for expiry states', () {
    final screen = File('lib/features/owner/screens/subscription_plans_screen.dart')
        .readAsStringSync();
    expect(screen, contains('OwnerPlanExpiryPresentation.stateFor(userModel, DateTime.now())'));
    expect(screen, contains('if (expiryState != OwnerPlanExpiryState.none)'));
    expect(screen, contains('OwnerPlanExpiryPresentation.message('));
    expect(screen, contains('VSPColors.warning'));
    expect(screen, contains('_loadPlans'));
  });
}
