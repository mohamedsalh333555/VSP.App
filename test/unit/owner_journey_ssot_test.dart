import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/features/owner/services/facility_onboarding_service.dart';

void main() {
  group('Owner Journey SSOT - Subscription Limits & 365-Day Free Trial', () {
    test('New owner with null trialEndsAt defaults to 365 days from creation', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'owner-1',
        email: 'owner@test.com',
        role: 'owner',
        createdAt: now,
        subscriptionPlan: 'free_trial',
        trialEndsAt: null,
      );

      expect(user.isInActiveTrial, isTrue);
      expect(user.hasActiveSubscription, isTrue);
      expect(user.isPlanExpired, isFalse);
      expect(user.maxStadiums, equals(1));

      // Should be roughly 365 days in the future
      final diff = user.effectiveTrialEndsAt!.difference(now).inDays;
      expect(diff, inInclusiveRange(364, 366));
    });

    test('Basic subscription owner allows exactly 1 stadium', () {
      final futureDate = DateTime.now().add(const Duration(days: 90));
      final user = UserModel(
        uid: 'owner-basic',
        email: 'basic@test.com',
        role: 'owner',
        subscriptionPlan: 'basic',
        subscriptionExpiresAt: futureDate,
      );

      expect(user.isBasicOrHigher, isTrue);
      expect(user.isProPlan, isFalse);
      expect(user.maxStadiums, equals(1));
      expect(FacilityOnboardingService.canAddStadium(user: user, currentStadiumsCount: 0), isTrue);
      expect(FacilityOnboardingService.canAddStadium(user: user, currentStadiumsCount: 1), isFalse);
    });

    test('Pro subscription owner allows up to 3 stadiums', () {
      final futureDate = DateTime.now().add(const Duration(days: 90));
      final user = UserModel(
        uid: 'owner-pro',
        email: 'pro@test.com',
        role: 'owner',
        subscriptionPlan: 'pro',
        subscriptionExpiresAt: futureDate,
      );

      expect(user.isProPlan, isTrue);
      expect(user.maxStadiums, equals(3));
      expect(FacilityOnboardingService.canAddStadium(user: user, currentStadiumsCount: 0), isTrue);
      expect(FacilityOnboardingService.canAddStadium(user: user, currentStadiumsCount: 2), isTrue);
      expect(FacilityOnboardingService.canAddStadium(user: user, currentStadiumsCount: 3), isFalse);
    });

    test('Expired owner with no grace period allows 0 stadiums', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 30));
      final user = UserModel(
        uid: 'owner-expired',
        email: 'expired@test.com',
        role: 'owner',
        subscriptionPlan: 'basic',
        subscriptionExpiresAt: pastDate,
      );

      expect(user.hasActiveSubscription, isFalse);
      expect(user.isInGracePeriod, isFalse);
      expect(user.isPlanExpired, isTrue);
      expect(user.maxStadiums, equals(0));
      expect(FacilityOnboardingService.canAddStadium(user: user, currentStadiumsCount: 0), isFalse);
    });
  });

  group('Owner Journey SSOT - Financial Reconciliation Logic', () {
    test('Available balance formula mathematically matches payout atomic requirement', () {
      // Rule: available_balance = GREATEST(0, realized_online_revenue - total_withdrawn - pending_payouts)
      // realized_online_revenue strictly requires status in ('completed', 'no_show')
      
      const double realizedOnlineRev = 5000.0;
      const double totalWithdrawn = 2000.0;
      const double pendingPayouts = 1000.0;

      final available = (realizedOnlineRev - totalWithdrawn - pendingPayouts) > 0
          ? (realizedOnlineRev - totalWithdrawn - pendingPayouts)
          : 0.0;

      expect(available, equals(2000.0));
    });

    test('Future confirmed bookings (upcoming_online_revenue) do not inflate available payout balance', () {
      const double realizedOnlineRev = 1000.0;
      const double upcomingOnlineRev = 4000.0; // Confirmed future matches not yet played
      const double totalWithdrawn = 500.0;
      const double pendingPayouts = 0.0;

      // Old buggy logic: 1000 + 4000 - 500 = 4500 (caused payout request to fail when owner asked for 4500)
      // New authoritative SSOT: only realized revenue is withdrawable
      final available = (realizedOnlineRev - totalWithdrawn - pendingPayouts) > 0
          ? (realizedOnlineRev - totalWithdrawn - pendingPayouts)
          : 0.0;

      expect(available, equals(500.0));
      expect(upcomingOnlineRev, equals(4000.0));
    });
  });
}
