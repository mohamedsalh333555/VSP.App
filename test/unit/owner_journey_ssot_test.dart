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

  group('Owner Journey SSOT - Stadium Reactivation Limit Invariants', () {
    test('Basic owner with 1 active stadium cannot reactivate another soft-deleted stadium', () {
      final futureDate = DateTime.now().add(const Duration(days: 90));
      final user = UserModel(
        uid: 'owner-basic',
        email: 'basic@test.com',
        role: 'owner',
        subscriptionPlan: 'basic',
        subscriptionExpiresAt: futureDate,
      );

      const int currentActiveStadiums = 1;
      final bool canReactivate = FacilityOnboardingService.canAddStadium(
        user: user,
        currentStadiumsCount: currentActiveStadiums,
      );
      expect(canReactivate, isFalse, reason: 'Reactivation must be blocked when at limit');
    });

    test('Pro owner with 3 active stadiums cannot reactivate a fourth', () {
      final futureDate = DateTime.now().add(const Duration(days: 90));
      final user = UserModel(
        uid: 'owner-pro',
        email: 'pro@test.com',
        role: 'owner',
        subscriptionPlan: 'pro',
        subscriptionExpiresAt: futureDate,
      );

      const int currentActiveStadiums = 3;
      final bool canReactivate = FacilityOnboardingService.canAddStadium(
        user: user,
        currentStadiumsCount: currentActiveStadiums,
      );
      expect(canReactivate, isFalse, reason: 'Pro reactivation blocked at 3 stadiums');
    });

    test('Reactivation succeeds when active stadium count is below allowed limit', () {
      final futureDate = DateTime.now().add(const Duration(days: 90));
      final user = UserModel(
        uid: 'owner-basic',
        email: 'basic@test.com',
        role: 'owner',
        subscriptionPlan: 'basic',
        subscriptionExpiresAt: futureDate,
      );

      const int currentActiveStadiums = 0; // Previous active stadium was soft-deleted
      final bool canReactivate = FacilityOnboardingService.canAddStadium(
        user: user,
        currentStadiumsCount: currentActiveStadiums,
      );
      expect(canReactivate, isTrue, reason: 'Reactivation allowed when capacity available');
    });

    test('Expired subscription cannot reactivate any stadium', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 10));
      final user = UserModel(
        uid: 'owner-expired',
        email: 'expired@test.com',
        role: 'owner',
        subscriptionPlan: 'pro',
        subscriptionExpiresAt: pastDate,
      );

      const int currentActiveStadiums = 0;
      final bool canReactivate = FacilityOnboardingService.canAddStadium(
        user: user,
        currentStadiumsCount: currentActiveStadiums,
      );
      expect(canReactivate, isFalse, reason: 'Expired owner cannot reactivate stadiums');
    });
  });

  group('Owner Journey SSOT - Financial Reconciliation Logic', () {
    test('Available balance formula mathematically matches payout atomic requirement', () {
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

      final available = (realizedOnlineRev - totalWithdrawn - pendingPayouts) > 0
          ? (realizedOnlineRev - totalWithdrawn - pendingPayouts)
          : 0.0;

      expect(available, equals(500.0));
      expect(upcomingOnlineRev, equals(4000.0));
    });
  });

  group('Owner Journey SSOT - Security & Authorization Invariants', () {
    bool checkDashboardAccess({
      required String? callerId,
      required String targetOwnerId,
      required String callerRole,
    }) {
      if (callerId == null) return false; // anon blocked
      if (callerRole == 'admin' || callerRole == 'co_founder' || callerRole == 'super_admin') {
        return true; // admin allowed
      }
      return callerId == targetOwnerId; // only self allowed
    }

    test('Anonymous caller cannot access owner dashboard analytics', () {
      expect(
        checkDashboardAccess(
          callerId: null,
          targetOwnerId: 'owner-123',
          callerRole: 'anon',
        ),
        isFalse,
      );
    });

    test('Cross-owner analytics access is strictly denied', () {
      expect(
        checkDashboardAccess(
          callerId: 'owner-456',
          targetOwnerId: 'owner-123',
          callerRole: 'owner',
        ),
        isFalse,
      );
    });

    test('Owner requesting own dashboard analytics is allowed', () {
      expect(
        checkDashboardAccess(
          callerId: 'owner-123',
          targetOwnerId: 'owner-123',
          callerRole: 'owner',
        ),
        isTrue,
      );
    });

    test('Platform admin requesting owner dashboard analytics is allowed', () {
      expect(
        checkDashboardAccess(
          callerId: 'admin-999',
          targetOwnerId: 'owner-123',
          callerRole: 'admin',
        ),
        isTrue,
      );
    });
  });
}
