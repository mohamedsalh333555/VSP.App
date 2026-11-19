import '../../../../core/models/user_model.dart';

/// UI-only owner subscription expiry notice.
///
/// This does not grant features, downgrade an account, or replace the server
/// source of truth. Subscription enforcement stays on the backend.
enum OwnerPlanExpiryState { none, trialExpired, paidExpired }

final class OwnerPlanExpiryPresentation {
  const OwnerPlanExpiryPresentation._();

  static OwnerPlanExpiryState stateFor(UserModel? user, DateTime now) {
    if (user == null || !user.isOwner) return OwnerPlanExpiryState.none;

    final activeTrial =
        user.trialEndsAt != null && user.trialEndsAt!.isAfter(now);
    final activePaid =
        user.subscriptionPlan == 'pro' &&
        user.subscriptionExpiresAt != null &&
        user.subscriptionExpiresAt!.isAfter(now);
    if (activeTrial || activePaid) return OwnerPlanExpiryState.none;

    if (user.subscriptionPlan == 'pro' &&
        user.subscriptionExpiresAt != null &&
        !user.subscriptionExpiresAt!.isAfter(now)) {
      return OwnerPlanExpiryState.paidExpired;
    }

    if (user.subscriptionPlan == 'free_trial' &&
        user.trialEndsAt != null &&
        !user.trialEndsAt!.isAfter(now)) {
      return OwnerPlanExpiryState.trialExpired;
    }

    return OwnerPlanExpiryState.none;
  }

  static String message(
    OwnerPlanExpiryState state, {
    required bool isArabic,
  }) {
    switch (state) {
      case OwnerPlanExpiryState.trialExpired:
        return isArabic
            ? 'انتهت فترة تجربة Pro. المزايا المجانية متاحة لك، ويمكنك الاشتراك للحصول على مزايا Pro.'
            : 'Your Pro trial has ended. Free features remain available, and you can subscribe for Pro benefits.';
      case OwnerPlanExpiryState.paidExpired:
        return isArabic
            ? 'انتهت مدة اشتراك Pro. المزايا المجانية متاحة لك؛ يمكنك تجديد الاشتراك من الباقات.'
            : 'Your Pro subscription has expired. Free features remain available; you can renew from the plans.';
      case OwnerPlanExpiryState.none:
        return '';
    }
  }
}
