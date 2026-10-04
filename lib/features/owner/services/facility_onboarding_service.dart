import '../../../core/models/user_model.dart';

/// Pure domain service managing facility onboarding business rules and validations.
class FacilityOnboardingService {
  const FacilityOnboardingService._();

  /// Determines whether the owner has stadium capacity remaining under their subscription tier.
  static bool canAddStadium({
    required UserModel? user,
    required int currentStadiumsCount,
  }) {
    if (user == null) return false;
    return currentStadiumsCount < user.maxStadiums;
  }

  /// Constructs the additionalData payload marking onboarding as confirmed.
  static Map<String, dynamic> buildOnboardingConfirmedPayload(
    Map<String, dynamic>? currentAdditionalData,
  ) {
    final updated = Map<String, dynamic>.from(currentAdditionalData ?? {});
    updated['isOnboardingConfirmed'] = true;
    return updated;
  }

  /// Formats the current plan name based on trial status and user locale.
  static String getPlanLabel({
    required UserModel user,
    required bool isArabic,
  }) {
    if (user.isProPlan) {
      if (user.isInActiveTrial) {
        return isArabic ? 'تجربة Pro (7 أيام)' : 'Pro Trial (7 Days)';
      }
      return isArabic ? 'باقة الاحتراف (Pro)' : 'Pro Plan';
    }
    return isArabic ? 'الباقة الأساسية (مجاناً)' : 'Basic Plan (Free)';
  }

  /// Calculates remaining trial days safely.
  static int getTrialDaysRemaining(UserModel user) {
    if (!user.isInActiveTrial || user.effectiveTrialEndsAt == null) {
      return 0;
    }
    final diff = user.effectiveTrialEndsAt!.difference(DateTime.now()).inDays;
    return diff.clamp(0, 999);
  }
}
