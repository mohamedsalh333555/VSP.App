import '../../../../core/models/user_model.dart';

/// Display-only subscription status. Never grants or revokes entitlements:
/// paid/trial access is checked by the authoritative backend.
enum OwnerSubscriptionBadgeState {
  unavailable,
  free,
  trial,
  pro,
  trialExpired,
  proExpired,
}

abstract final class OwnerSubscriptionStatusPresentation {
  static OwnerSubscriptionBadgeState stateFor(
    UserModel? user,
    DateTime now,
  ) {
    if (user == null || !user.isOwner) {
      return OwnerSubscriptionBadgeState.unavailable;
    }
    if (user.subscriptionPlan == 'pro' &&
        user.subscriptionExpiresAt?.isAfter(now) == true) {
      return OwnerSubscriptionBadgeState.pro;
    }
    if (user.trialEndsAt?.isAfter(now) == true) {
      return OwnerSubscriptionBadgeState.trial;
    }
    if (user.subscriptionPlan == 'pro' &&
        user.subscriptionExpiresAt != null) {
      return OwnerSubscriptionBadgeState.proExpired;
    }
    if (user.subscriptionPlan == 'free_trial' && user.trialEndsAt != null) {
      return OwnerSubscriptionBadgeState.trialExpired;
    }
    if (user.subscriptionPlan == 'basic' ||
        user.subscriptionPlan == 'free' ||
        user.subscriptionPlan == 'free_trial') {
      return OwnerSubscriptionBadgeState.free;
    }
    return OwnerSubscriptionBadgeState.unavailable;
  }

  static String label(
    OwnerSubscriptionBadgeState state, {
    required bool isArabic,
  }) {
    switch (state) {
      case OwnerSubscriptionBadgeState.pro:
        return isArabic ? 'اشتراك Pro' : 'Pro subscription';
      case OwnerSubscriptionBadgeState.trial:
        return isArabic ? 'تجربة Pro' : 'Pro trial';
      case OwnerSubscriptionBadgeState.trialExpired:
        return isArabic ? 'انتهت التجربة' : 'Trial ended';
      case OwnerSubscriptionBadgeState.proExpired:
        return isArabic ? 'انتهى اشتراك Pro' : 'Pro expired';
      case OwnerSubscriptionBadgeState.free:
        return isArabic ? 'مجاني' : 'Free';
      case OwnerSubscriptionBadgeState.unavailable:
        return isArabic ? 'الاشتراك غير متاح' : 'Plan unavailable';
    }
  }

  static bool getIsWarning(OwnerSubscriptionBadgeState state) =>
      state == OwnerSubscriptionBadgeState.trialExpired ||
      state == OwnerSubscriptionBadgeState.proExpired ||
      state == OwnerSubscriptionBadgeState.unavailable;

  static bool getIsActivePro(OwnerSubscriptionBadgeState state) =>
      state == OwnerSubscriptionBadgeState.pro ||
      state == OwnerSubscriptionBadgeState.trial;
}
