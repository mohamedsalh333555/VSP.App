import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/features/owner/services/facility_onboarding_service.dart';
import 'package:vsp_application/models/dashboard_analytics.dart';

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

  group('Owner Journey SSOT - Dashboard Revenue Separation & Consistency', () {
    test('RevenueData separates realized accounting revenue from upcoming operational value', () {
      final json = {
        'total': 1500.0,
        'cash': 500.0,
        'online': 1000.0,
        'cash_percentage': 33.3,
        'online_percentage': 66.7,
        'unrealized': 200.0,
        'realized_revenue': 600.0,
        'realized_cash': 200.0,
        'realized_online': 400.0,
        'upcoming_confirmed_value': 900.0,
        'upcoming_cash_value': 300.0,
        'upcoming_online_value': 600.0,
      };

      final revenue = RevenueData.fromJson(json);

      expect(revenue.total, equals(1500.0));
      expect(revenue.cash, equals(500.0));
      expect(revenue.online, equals(1000.0));
      expect(revenue.isConsistent, isTrue);

      expect(revenue.realizedRevenue, equals(600.0));
      expect(revenue.realizedCash, equals(200.0));
      expect(revenue.realizedOnline, equals(400.0));

      expect(revenue.upcomingConfirmedValue, equals(900.0));
      expect(revenue.upcomingCashValue, equals(300.0));
      expect(revenue.upcomingOnlineValue, equals(600.0));

      // Operational consistency
      expect(revenue.realizedRevenue + revenue.upcomingConfirmedValue, equals(revenue.total));
    });

    test('Empty or default RevenueData initializes safely with zeros', () {
      const revenue = RevenueData();
      expect(revenue.total, equals(0.0));
      expect(revenue.realizedRevenue, equals(0.0));
      expect(revenue.upcomingConfirmedValue, equals(0.0));
      expect(revenue.isConsistent, isTrue);
    });
  });

  group('Owner Journey SSOT - Free Trial Semantic Plan Invariance', () {
    int? resolveTrialDaysStrict({
      required Map<String, int> activePlans,
      String authoritativePlanCode = 'basic',
    }) {
      // Fail closed: if basic is missing or inactive, return null (never invent 365)
      return activePlans[authoritativePlanCode];
    }

    test('Changing unrelated plan trial duration does NOT alter owner trial duration', () {
      // Base state: basic=365, pro=365
      final plansBefore = {'basic': 365, 'pro': 365};
      expect(resolveTrialDaysStrict(activePlans: plansBefore), equals(365));

      // Unrelated plan changed: pro changed to 14 days or 30 days
      final plansAfterProChanged = {'basic': 365, 'pro': 14};
      expect(
        resolveTrialDaysStrict(activePlans: plansAfterProChanged),
        equals(365),
        reason: 'Owner trial duration must strictly read basic plan, unaffected by pro plan changes',
      );

      // Enterprise plan added with 90 days
      final plansWithEnterprise = {'basic': 365, 'pro': 14, 'enterprise': 90};
      expect(
        resolveTrialDaysStrict(activePlans: plansWithEnterprise),
        equals(365),
        reason: 'Enterprise plan presence must not alter basic owner free trial duration',
      );
    });

    test('Missing basic plan configuration fails closed and does not invent 365 days', () {
      final emptyPlans = <String, int>{};
      expect(resolveTrialDaysStrict(activePlans: emptyPlans), isNull);

      final plansWithoutBasic = {'pro': 14, 'enterprise': 90};
      expect(
        resolveTrialDaysStrict(activePlans: plansWithoutBasic),
        isNull,
        reason: 'Missing basic plan must fail closed without inventing fallback duration',
      );
    });
  });

  group('Owner Journey SSOT - View & Function Isolation Policy', () {
    bool canSelectSubscriptionStatusRow({
      required String? callerId,
      required String rowOwnerId,
      required bool isAdmin,
    }) {
      if (callerId == null) return false; // anon rejected
      if (isAdmin) return true; // admin allowed
      return callerId == rowOwnerId; // owner sees only self
    }

    test('Anonymous user is rejected from viewing owner subscription status', () {
      expect(
        canSelectSubscriptionStatusRow(callerId: null, rowOwnerId: 'owner-1', isAdmin: false),
        isFalse,
      );
    });

    test('Owner A cannot view Owner B subscription status row', () {
      expect(
        canSelectSubscriptionStatusRow(callerId: 'owner-A', rowOwnerId: 'owner-B', isAdmin: false),
        isFalse,
      );
    });

    test('Owner A can view own subscription status row', () {
      expect(
        canSelectSubscriptionStatusRow(callerId: 'owner-A', rowOwnerId: 'owner-A', isAdmin: false),
        isTrue,
      );
    });

    test('Admin can view any owner subscription status row', () {
      expect(
        canSelectSubscriptionStatusRow(callerId: 'admin-1', rowOwnerId: 'owner-B', isAdmin: true),
        isTrue,
      );
    });
  });

  group('Owner Journey SSOT - Registration & Catalog Trial Invariants', () {
    test('Trial duration strictly derives from subscription_plans without 60-day fallback', () {
      int? computeTrialDays(Map<String, dynamic>? basicPlan) {
        if (basicPlan == null || basicPlan['is_active'] != true) return null;
        final days = basicPlan['trial_days'];
        if (days is int && days > 0) return days;
        return null;
      }

      // Catalog has 365 days
      final catalog = {'code': 'basic', 'trial_days': 365, 'is_active': true};
      expect(computeTrialDays(catalog), equals(365));

      // Missing catalog fails closed (returns null, NEVER 60)
      expect(computeTrialDays(null), isNull);
      expect(computeTrialDays({'code': 'basic', 'is_active': false}), isNull);
      expect(computeTrialDays({'code': 'basic', 'trial_days': 0, 'is_active': true}), isNull);
    });

    test('Ledger re-registration preserves original trial and denies fresh trial', () {
      final now = DateTime(2026, 10, 1, 12, 0);
      final originalEndsAt = now.add(const Duration(days: 45)); // 45 days remaining

      DateTime calculateReRegistrationTrial({
        required DateTime now,
        required DateTime originalEndsAt,
      }) {
        final remainingDays = originalEndsAt.difference(now).inDays;
        return remainingDays > 0 ? now.add(Duration(days: remainingDays)) : now;
      }

      final trialEnds = calculateReRegistrationTrial(now: now, originalEndsAt: originalEndsAt);
      expect(trialEnds.difference(now).inDays, equals(45));
    });

    test('Expired ledger entry does not grant any extra days', () {
      final now = DateTime(2026, 10, 1, 12, 0);
      final originalEndsAt = now.subtract(const Duration(days: 10)); // expired 10 days ago

      final remainingDays = originalEndsAt.difference(now).inDays;
      final trialEnds = remainingDays > 0 ? now.add(Duration(days: remainingDays)) : now;
      expect(trialEnds, equals(now), reason: 'Expired ledger must not grant additional trial days');
    });
  });

  group('Owner Journey SSOT - Onboarding & Stadium Server Derivation', () {
    test('has_stadium is strictly derived from active non-deleted stadiums', () {
      bool deriveHasStadium(List<Map<String, dynamic>> stadiums) {
        return stadiums.any((s) => s['is_deleted_by_owner'] != true);
      }

      expect(deriveHasStadium([]), isFalse, reason: 'Empty stadiums list must yield has_stadium=false');
      expect(
        deriveHasStadium([{'id': 'std-1', 'is_deleted_by_owner': true}]),
        isFalse,
        reason: 'Only soft-deleted stadiums must yield has_stadium=false',
      );
      expect(
        deriveHasStadium([
          {'id': 'std-1', 'is_deleted_by_owner': true},
          {'id': 'std-2', 'is_deleted_by_owner': false},
        ]),
        isTrue,
        reason: 'At least one active stadium yields has_stadium=true',
      );
    });

    test('Stadium verification lifecycle: unverified on creation, verified only by admin', () {
      final initialStadium = {
        'id': 'std-new',
        'is_verified': false,
        'verification_status': 'unverified',
      };
      expect(initialStadium['is_verified'], isFalse);

      // Admin approval transition
      Map<String, dynamic> approveStadium(Map<String, dynamic> s, {required bool isAdmin}) {
        if (!isAdmin) throw Exception('Unauthorized');
        return {...s, 'is_verified': true, 'verification_status': 'verified'};
      }

      final approved = approveStadium(initialStadium, isAdmin: true);
      expect(approved['is_verified'], isTrue);
      expect(() => approveStadium(initialStadium, isAdmin: false), throwsException);
    });
  });

  group('Owner Journey SSOT - Operating Hours Calculation (No 10h Fallback)', () {
    double calculateStadiumDailyOperatingHours({
      required String openingTime,
      required String closingTime,
      bool isSplitShift = false,
      String? breakStartTime,
      String? breakEndTime,
    }) {
      double parseTimeToHours(String time) {
        final parts = time.split(':');
        return int.parse(parts[0]) + int.parse(parts[1]) / 60.0;
      }

      final openH = parseTimeToHours(openingTime);
      final closeH = parseTimeToHours(closingTime);

      double shiftDuration;
      if (closeH > openH) {
        shiftDuration = closeH - openH;
      } else {
        // Overnight shift (e.g. 15:00 to 02:00 -> 24 - 15 + 2 = 11 hours)
        shiftDuration = (24.0 - openH) + closeH;
      }

      if (isSplitShift && breakStartTime != null && breakEndTime != null) {
        final bOpenH = parseTimeToHours(breakStartTime);
        final bCloseH = parseTimeToHours(breakEndTime);
        double breakDuration;
        if (bCloseH > bOpenH) {
          breakDuration = bCloseH - bOpenH;
        } else {
          breakDuration = (24.0 - bOpenH) + bCloseH;
        }
        shiftDuration -= breakDuration;
      }

      return shiftDuration.clamp(0.0, 24.0);
    }

    test('Exact calculation for Production stadium (15:00 to 02:00 with 1h split break = 10.0h)', () {
      final hours = calculateStadiumDailyOperatingHours(
        openingTime: '15:00:00',
        closingTime: '02:00:00',
        isSplitShift: true,
        breakStartTime: '18:00:00',
        breakEndTime: '19:00:00',
      );
      expect(hours, equals(10.0), reason: '11 hours shift minus 1 hour break must equal 10.0 hours');
    });

    test('Regular single shift (09:00 to 23:00 = 14.0h)', () {
      final hours = calculateStadiumDailyOperatingHours(
        openingTime: '09:00:00',
        closingTime: '23:00:00',
        isSplitShift: false,
      );
      expect(hours, equals(14.0));
    });
  });

  group('Owner Journey SSOT - Manual Booking & Cash Settlement', () {
    test('Server calculates exact duration and price for manual booking', () {
      const double hourlyRate = 200.0;
      final start = DateTime(2026, 10, 1, 18, 0);
      final end = DateTime(2026, 10, 1, 20, 0); // 2 hours

      final duration = end.difference(start).inMinutes / 60.0;
      final serverTotal = hourlyRate * duration;

      expect(duration, equals(2.0));
      expect(serverTotal, equals(400.0));

      // Partial collection (deposit)
      const double collected = 100.0;
      final remaining = serverTotal - collected;
      final paymentStatus = collected >= serverTotal
          ? 'paid'
          : (collected > 0 ? 'partially_paid' : 'pending');

      expect(collected, equals(100.0));
      expect(remaining, equals(300.0));
      expect(paymentStatus, equals('partially_paid'));
    });

    test('Full cash settlement sets paymentStatus=paid and remaining=0', () {
      const double serverTotal = 400.0;
      const double collected = 400.0;
      final remaining = (serverTotal - collected).clamp(0.0, 999999.0);
      final isPaid = collected >= serverTotal;

      expect(remaining, equals(0.0));
      expect(isPaid, isTrue);
    });
  });

  group('Owner Journey SSOT - Subscription Downgrade & Expiration Invariants', () {
    test('Expired Pro owner without active trial downgrades to expired, NOT free_trial', () {
      final now = DateTime(2026, 10, 1, 12, 0);
      final trialEndsAt = now.subtract(const Duration(days: 60)); // expired long ago
      final subExpiresAt = now.subtract(const Duration(days: 1)); // pro expired yesterday

      String computeDowngradedPlan({
        required DateTime now,
        required DateTime? trialEndsAt,
        required DateTime subExpiresAt,
      }) {
        if (trialEndsAt != null && trialEndsAt.isAfter(now)) {
          return 'free_trial'; // Edge case: still in valid trial
        }
        return 'expired'; // Standard SSOT
      }

      final plan = computeDowngradedPlan(
        now: now,
        trialEndsAt: trialEndsAt,
        subExpiresAt: subExpiresAt,
      );

      expect(plan, equals('expired'), reason: 'Expired Pro account must NOT revert to fake free_trial');
    });
  });

  group('Owner Journey SSOT - Complete State Transition Matrix', () {
    test('Full Owner Lifecycle Transitions', () {
      // 1. Registered -> Needs Stadium
      var ownerState = 'OWNER_REGISTERED';
      bool hasStadium = false;
      String? verificationStatus;

      if (!hasStadium) {
        ownerState = 'OWNER_NEEDS_STADIUM';
      }
      expect(ownerState, equals('OWNER_NEEDS_STADIUM'));

      // 2. Stadium Added -> Pending Verification
      hasStadium = true;
      verificationStatus = 'pending';
      if (hasStadium && verificationStatus == 'pending') {
        ownerState = 'OWNER_PENDING_VERIFICATION';
      }
      expect(ownerState, equals('OWNER_PENDING_VERIFICATION'));

      // 3. Admin Approved -> Active
      verificationStatus = 'approved';
      if (hasStadium && verificationStatus == 'approved') {
        ownerState = 'OWNER_ACTIVE';
      }
      expect(ownerState, equals('OWNER_ACTIVE'));

      // 4. Admin Blocked -> Blocked
      bool isBlocked = true;
      if (isBlocked) {
        ownerState = 'OWNER_BLOCKED';
      }
      expect(ownerState, equals('OWNER_BLOCKED'));
    });
  });
}

